<?php
/**
 * Cache Helper cho API
 * Tối ưu tốc độ API với Memcached
 */

class CacheHelper {
    private $memcached;
    private $default_ttl = 300; // 5 phút mặc định
    
    public function __construct() {
        $this->memcached = new Memcached();
        $this->memcached->addServer('127.0.0.1', 11211);
    }
    
    /**
     * Lấy dữ liệu từ cache hoặc database
     * @param string $cache_key - Key cache
     * @param callable $callback - Function load từ database
     * @param int $ttl - Thời gian cache (giây)
     * @return mixed
     */
    public function getOrSet($cache_key, $callback, $ttl = null) {
        $ttl = $ttl ?? $this->default_ttl;
        
        // Thử lấy từ cache trước
        $data = $this->memcached->get($cache_key);
        
        if ($data === false) {
            // Cache miss - load từ database
            $data = $callback();
            
            // Lưu vào cache
            if ($data !== false) {
                $this->memcached->set($cache_key, $data, $ttl);
            }
        }
        
        return $data;
    }
    
    /**
     * Xóa cache theo key
     */
    public function delete($cache_key) {
        return $this->memcached->delete($cache_key);
    }
    
    /**
     * Xóa tất cả cache
     */
    public function flush() {
        return $this->memcached->flush();
    }
    
    /**
     * Tạo cache key với parameters
     */
    public function createKey($prefix, $params = []) {
        $key = $prefix;
        if (!empty($params)) {
            $key .= '_' . md5(serialize($params));
        }
        return $key;
    }
}

// Global instance
$cache = new CacheHelper();
?>
