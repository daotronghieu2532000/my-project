<?php
/**
 * Cấu hình ZNS Zalo
 * 
 * Lưu ý: Cần cập nhật các thông tin sau từ tài khoản Zalo Cloud của bạn:
 * - ACCESS_TOKEN: Lấy từ https://developers.zalo.me/app/{app_id}/access-token
 * - REFRESH_TOKEN: Lấy cùng lúc với Access Token
 * - APP_ID: Application ID từ Zalo Cloud
 * - APP_SECRET: Application Secret từ Zalo Cloud
 * - OA_ID: Official Account ID
 * - TEMPLATE_ID: Template ID đã được duyệt trên Zalo Cloud
 */

// Cấu hình ZNS
define('ZNS_ACCESS_TOKEN', 'khe2TfkDhJEwlGDodewWCxwp2dIVcDXAoiesJR2X_6IMw2LdyABCM8li66FIdSv3iDmqUfQhx3cvmnukcOAp1zlmRJoVkTidl8fvDD2Yq0M0tZj1z8Zq1u_-017jgTO0YTG39_UO_p67mb0k-_2x7RAZLI-Ty9ejlCTc6zxobLczXLvcsFMmLRcxRHANovKNvfHb8u7ap1ZDc2yizl_5QB3CRM_ve9feXuXKJzh7fdcxY11BcD_3SDIt1tdqolj2cFeXPhZArMF1fNTAhzg2Q__oNr-jbVLztAaTJwZU_tFVb19hdwZXBjtwFpEEb9Saoj1AEQgvWJkDrNK4rPlN1fla7aNRikrql-GpC9pNxZVCbH4rkEJ9SDYv1LAS-TProSeVSOQRoKZ2goDzc9_SJkYe3taM1Pjmc96gFm'); // Access Token (ngắn hạn ~1-2 giờ)
define('ZNS_REFRESH_TOKEN', 'tR9-GdcCAc3TjNz6V8ydODcxTa1zcMuctjbVTGMzKnBVmGGmBeS3V--wDprCWWKRZk5NIbwVRGgtp3jEQv0XQC_QSJGweN8K_CSdQncXSIRCprbK1urG8l7EP0qKWM4evCzFTpoWU07CnL5yEfPu8jskMtGTn5qDsRjqN0t_V2ZgnYbt7uquKA7a6H9BiandlzL-D626Un7BmLvn8eD6FkZg4HWPlXy_uVys1H-7PoRQqaPp1gz3BE3j46GPfG8HnF1GGMAHHMIM-6vAIQj3BgxaR7nNWM5SiiT5FXN_I1lfcMnj3w5YECFZHNnzZN0dsROzVZly12pkho1JEyzvTilsG0bXi0releHL5dJjNZI3krL1Qk1UB8wBVrqljYn-YlzXBK74E5YJ-NKNGgzPPbH8amnW5tgGBMm'); // Refresh Token (dài hạn ~30 ngày)
define('ZNS_APP_ID', '3972457551268168177'); // App ID từ Zalo Cloud - CẦN CẬP NHẬT
define('ZNS_APP_SECRET', 'PedQcRl79956tEHG2dC9'); // App Secret từ Zalo Cloud - CẦN CẬP NHẬT (lấy từ https://developers.zalo.me/app/{app_id}/basic-info)
define('ZNS_OA_ID', '2813091073440910336'); // OA ID (Official Account ID)
define('ZNS_TEMPLATE_ID', '505716'); // Template ID đã được duyệt

// Đường dẫn file cache token (để lưu token mới sau khi refresh)
define('ZNS_TOKEN_CACHE_FILE', __DIR__ . '/zns_token_cache.json');

// Hoặc có thể lưu trong file config riêng và include
// require_once __DIR__ . '/zns_config_secret.php';

