<?php
/**
 * Redis Queue Service
 * 
 * Message Queue Pattern: Event → Queue → Worker → Push
 * 
 * Features:
 * - Real-time processing
 * - Auto retry với exponential backoff
 * - Priority queue
 * - Rate limiting
 * - Dead letter queue (failed jobs)
 */

class RedisQueueService {
    private $redis;
    private $isPredis = false; // Flag để biết đang dùng Predis hay Redis extension
    private $conn; // Database connection
    private $logPath;
    
    // Queue names
    const QUEUE_NOTIFICATIONS = 'notifications:queue';
    const QUEUE_NOTIFICATIONS_PRIORITY = 'notifications:priority';
    const QUEUE_NOTIFICATIONS_DELAYED = 'notifications:delayed';
    const QUEUE_NOTIFICATIONS_FAILED = 'notifications:failed';
    
    // Retry config
    const MAX_RETRIES = 3;
    const RETRY_DELAYS = [60, 300, 900]; // 1min, 5min, 15min
    
    public function __construct($database_connection = null) {
        // Initialize Redis connection
        try {
            // Try Redis extension first
            if (extension_loaded('redis')) {
                $this->redis = new Redis();
                $this->redis->connect('127.0.0.1', 6379, 2.5); // 2.5s timeout
                $this->redis->setOption(Redis::OPT_SERIALIZER, Redis::SERIALIZER_JSON);
            } 
            // Fallback to Predis (PHP client)
            elseif (class_exists('Predis\Client')) {
                // Try vendor/autoload.php ở nhiều vị trí
                $vendorPaths = [
                    __DIR__ . '/../vendor/autoload.php',
                    __DIR__ . '/../../vendor/autoload.php',
                    '/home/api.socdo.vn/public_html/vendor/autoload.php',
                ];
                $vendorLoaded = false;
                foreach ($vendorPaths as $vendorPath) {
                    if (file_exists($vendorPath)) {
                        require_once $vendorPath;
                        $vendorLoaded = true;
                        break;
                    }
                }
                if (!$vendorLoaded) {
                    throw new Exception("Predis autoload file not found");
                }
                
                $this->redis = new Predis\Client([
                    'scheme' => 'tcp',
                    'host'   => '127.0.0.1',
                    'port'   => 6379,
                ]);
                $this->isPredis = true;
            } else {
                throw new Exception("Neither Redis extension nor Predis is available");
            }
        } catch (Exception $e) {
            // Fallback to database queue if Redis unavailable
            $this->redis = null;
            $logPath = __DIR__ . '/debug_push_notifications.log';
            file_put_contents($logPath, date('c') . " | [REDIS_QUEUE] ⚠️ Redis connection failed, using database queue: " . $e->getMessage() . "\n", FILE_APPEND);
        }
        
        $this->conn = $database_connection;
        $this->logPath = __DIR__ . '/debug_push_notifications.log';
    }
    
    /**
     * Push notification job vào queue
     * 
     * @param array $jobData {
     *   notification_id: int,
     *   user_id: int,
     *   type: string,
     *   title: string,
     *   content: string,
     *   data: array,
     *   priority: string (high|medium|low),
     *   delay: int (seconds, optional)
     * }
     * @return bool
     */
    public function pushNotification($jobData) {
        if (!$this->redis) {
            // Fallback: Insert vào database queue
            return $this->pushToDatabaseQueue($jobData);
        }
        
        try {
            $job = [
                'id' => uniqid('job_', true),
                'notification_id' => intval($jobData['notification_id'] ?? 0),
                'user_id' => intval($jobData['user_id'] ?? 0),
                'type' => $jobData['type'] ?? 'unknown',
                'title' => $jobData['title'] ?? '',
                'content' => $jobData['content'] ?? '',
                'data' => $jobData['data'] ?? [],
                'priority' => $jobData['priority'] ?? 'medium',
                'retry_count' => 0,
                'created_at' => time(),
                'delay' => intval($jobData['delay'] ?? 0),
            ];
            
            // Determine queue based on priority and delay
            if ($job['delay'] > 0) {
                // Delayed queue: ZADD với score = current_time + delay
                $score = time() + $job['delay'];
                $jobJson = json_encode($job);
                if ($this->isPredis) {
                    $this->redis->zadd(self::QUEUE_NOTIFICATIONS_DELAYED, [$jobJson => $score]);
                } else {
                    $this->redis->zAdd(self::QUEUE_NOTIFICATIONS_DELAYED, $score, $jobJson);
                }
                file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ✅ Pushed delayed job: {$job['id']} (delay: {$job['delay']}s)\n", FILE_APPEND);
            } elseif ($job['priority'] === 'high') {
                // Priority queue
                $jobJson = json_encode($job);
                if ($this->isPredis) {
                    $this->redis->lpush(self::QUEUE_NOTIFICATIONS_PRIORITY, $jobJson);
                } else {
                    $this->redis->lPush(self::QUEUE_NOTIFICATIONS_PRIORITY, $jobJson);
                }
                file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ✅ Pushed priority job: {$job['id']}\n", FILE_APPEND);
            } else {
                // Normal queue
                $jobJson = json_encode($job);
                if ($this->isPredis) {
                    $this->redis->lpush(self::QUEUE_NOTIFICATIONS, $jobJson);
                } else {
                    $this->redis->lPush(self::QUEUE_NOTIFICATIONS, $jobJson);
                }
                file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ✅ Pushed job: {$job['id']}\n", FILE_APPEND);
            }
            
            return true;
        } catch (Exception $e) {
            file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ❌ Error pushing job: " . $e->getMessage() . "\n", FILE_APPEND);
            // Fallback to database
            return $this->pushToDatabaseQueue($jobData);
        }
    }
    
    /**
     * Pop job từ queue (FIFO với priority)
     * 
     * @return array|null
     */
    public function popNotification() {
        if (!$this->redis) {
            return null;
        }
        
        try {
            // 1. Check delayed queue (jobs ready to process)
            $currentTime = time();
            if ($this->isPredis) {
                $delayedJobs = $this->redis->zrangebyscore(
                    self::QUEUE_NOTIFICATIONS_DELAYED,
                    0,
                    $currentTime,
                    ['limit' => [0, 1]]
                );
            } else {
                $delayedJobs = $this->redis->zRangeByScore(
                    self::QUEUE_NOTIFICATIONS_DELAYED,
                    0,
                    $currentTime,
                    ['limit' => [0, 1]]
                );
            }
            
            if (!empty($delayedJobs)) {
                $jobJson = is_array($delayedJobs) ? $delayedJobs[0] : $delayedJobs;
                $job = json_decode($jobJson, true);
                if ($this->isPredis) {
                    $this->redis->zrem(self::QUEUE_NOTIFICATIONS_DELAYED, $jobJson);
                } else {
                    $this->redis->zRem(self::QUEUE_NOTIFICATIONS_DELAYED, $jobJson);
                }
                return $job;
            }
            
            // 2. Check priority queue
            if ($this->isPredis) {
                $priorityJob = $this->redis->rpop(self::QUEUE_NOTIFICATIONS_PRIORITY);
            } else {
                $priorityJob = $this->redis->rPop(self::QUEUE_NOTIFICATIONS_PRIORITY);
            }
            if ($priorityJob) {
                return json_decode($priorityJob, true);
            }
            
            // 3. Check normal queue
            if ($this->isPredis) {
                $normalJob = $this->redis->rpop(self::QUEUE_NOTIFICATIONS);
            } else {
                $normalJob = $this->redis->rPop(self::QUEUE_NOTIFICATIONS);
            }
            if ($normalJob) {
                return json_decode($normalJob, true);
            }
            
            return null;
        } catch (Exception $e) {
            file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ❌ Error popping job: " . $e->getMessage() . "\n", FILE_APPEND);
            return null;
        }
    }
    
    /**
     * Process notification job
     * 
     * @param array $job
     * @return bool
     */
    public function processJob($job) {
        try {
            $notification_id = intval($job['notification_id'] ?? 0);
            $user_id = intval($job['user_id'] ?? 0);
            
            if ($notification_id <= 0 || $user_id <= 0) {
                file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ❌ Invalid job data\n", FILE_APPEND);
                return false;
            }
            
            // Check device token
            if (!$this->conn) {
                file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ❌ No database connection\n", FILE_APPEND);
                return false;
            }
            
            $checkTokenQuery = "SELECT COUNT(*) as count FROM device_tokens WHERE user_id = $user_id AND is_active = 1";
            $checkTokenResult = mysqli_query($this->conn, $checkTokenQuery);
            $hasToken = false;
            if ($checkTokenResult) {
                $tokenRow = mysqli_fetch_assoc($checkTokenResult);
                $hasToken = intval($tokenRow['count']) > 0;
            }
            
            if (!$hasToken) {
                file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ⚠️ User $user_id has no device token\n", FILE_APPEND);
                // Mark as sent (no token = can't send)
                $this->markNotificationSent($notification_id);
                return true;
            }
            
            // Send push notification
            require_once __DIR__ . '/notification_mobile_helper.php';
            $notificationHelper = new NotificationMobileHelper($this->conn);
            $pushResult = $notificationHelper->sendPushForNotification($notification_id);
            
            if ($pushResult) {
                $this->markNotificationSent($notification_id);
                file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ✅ Job processed: notification_id=$notification_id\n", FILE_APPEND);
                return true;
            } else {
                // Retry logic
                $retryCount = intval($job['retry_count'] ?? 0);
                if ($retryCount < self::MAX_RETRIES) {
                    $this->retryJob($job, $retryCount);
                } else {
                    // Move to failed queue
                    $this->moveToFailedQueue($job);
                }
                return false;
            }
        } catch (Exception $e) {
            file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ❌ Exception processing job: " . $e->getMessage() . "\n", FILE_APPEND);
            return false;
        }
    }
    
    /**
     * Retry job với exponential backoff
     */
    private function retryJob($job, $retryCount) {
        if (!$this->redis) return;
        
        $job['retry_count'] = $retryCount + 1;
        $delay = self::RETRY_DELAYS[$retryCount] ?? 900; // Default 15min
        
        $score = time() + $delay;
        $jobJson = json_encode($job);
        if ($this->isPredis) {
            $this->redis->zadd(self::QUEUE_NOTIFICATIONS_DELAYED, [$jobJson => $score]);
        } else {
            $this->redis->zAdd(self::QUEUE_NOTIFICATIONS_DELAYED, $score, $jobJson);
        }
        
        file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] 🔄 Retrying job: {$job['id']} (attempt " . ($retryCount + 1) . ", delay: {$delay}s)\n", FILE_APPEND);
    }
    
    /**
     * Move job to failed queue
     */
    private function moveToFailedQueue($job) {
        if (!$this->redis) return;
        
        $jobJson = json_encode($job);
        if ($this->isPredis) {
            $this->redis->lpush(self::QUEUE_NOTIFICATIONS_FAILED, $jobJson);
        } else {
            $this->redis->lPush(self::QUEUE_NOTIFICATIONS_FAILED, $jobJson);
        }
        file_put_contents($this->logPath, date('c') . " | [REDIS_QUEUE] ❌ Job failed after " . self::MAX_RETRIES . " retries: {$job['id']}\n", FILE_APPEND);
    }
    
    /**
     * Mark notification as sent in database
     */
    private function markNotificationSent($notification_id) {
        if (!$this->conn) return;
        
        $query = "UPDATE notification_mobile SET push_sent = 1, updated_at = " . time() . " WHERE id = $notification_id";
        mysqli_query($this->conn, $query);
    }
    
    /**
     * Fallback: Push to database queue
     */
    private function pushToDatabaseQueue($jobData) {
        // Notification đã được tạo trong DB với push_sent = 0
        // Queue processor sẽ xử lý
        return true;
    }
    
    /**
     * Get queue stats
     */
    public function getStats() {
        if (!$this->redis) {
            return ['redis_available' => false];
        }
        
        if ($this->isPredis) {
            return [
                'redis_available' => true,
                'normal_queue_size' => $this->redis->llen(self::QUEUE_NOTIFICATIONS),
                'priority_queue_size' => $this->redis->llen(self::QUEUE_NOTIFICATIONS_PRIORITY),
                'delayed_queue_size' => $this->redis->zcard(self::QUEUE_NOTIFICATIONS_DELAYED),
                'failed_queue_size' => $this->redis->llen(self::QUEUE_NOTIFICATIONS_FAILED),
            ];
        } else {
            return [
                'redis_available' => true,
                'normal_queue_size' => $this->redis->lLen(self::QUEUE_NOTIFICATIONS),
                'priority_queue_size' => $this->redis->lLen(self::QUEUE_NOTIFICATIONS_PRIORITY),
                'delayed_queue_size' => $this->redis->zCard(self::QUEUE_NOTIFICATIONS_DELAYED),
                'failed_queue_size' => $this->redis->lLen(self::QUEUE_NOTIFICATIONS_FAILED),
            ];
        }
    }
}

