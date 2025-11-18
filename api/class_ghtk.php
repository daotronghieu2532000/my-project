<?php
class class_ghtk extends class_manage {
    // Khai báo properties của class
    private $link_live;
    private $token_live;
    private $link_test;
    private $token_test;
    function __construct() {
        // Gán giá trị cho properties
        $this->link_live = 'https://services.giaohangtietkiem.vn';
        $this->token_live = '2OPRiYz04BgkBlodKVQvrB0D6ieLItuTBOXIEF4';
        $this->link_test = 'https://services-staging.ghtklab.com';
        $this->token_test = 'A3iVbzqsUhIqZZu0CfXBWi7vhsMtbP5ydSOcjl';
    }
    // tính phí ship
    function ship_fee($data,$live) {
      //   $data = array(
      //     "pick_province" => "Hà Nội",
      //     "pick_district" => "Quận Hai Bà Trưng",
      //     "province" => "Hà nội",
      //     "district" => "Quận Cầu Giấy",
      //     "address" => "P.503 tòa nhà Auu Việt, số 1 Lê Đức Thọ",
      //     "weight" => 1000,
      //     "value" => 3000000,
      //     "transport" => "fly",
      //     "deliver_option" => "xteam",
      //     "tags" => [1,7]
      // );
      if($live) {
        $link = $this->link_live;
        $token = $this->token_live;
      } else {
        $link = $this->link_test;
        $token = $this->token_test;
      }
      $curl = curl_init();
      curl_setopt_array($curl, array(
          CURLOPT_URL => $link . "/services/shipment/fee?" . http_build_query($data),
          CURLOPT_RETURNTRANSFER => true,
          CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
          CURLOPT_HTTPHEADER => array(
              "Token: " . $token,
              "X-Client-Source: S22993698",
          ),
      ));
      $response = curl_exec($curl);
      curl_close($curl);
      return $response;
  }
  // trạng thái đơn hàng
  function get_shipment_info($shipmentId,$live) {
    if($live) {
      $link = $this->link_live;
      $token = $this->token_live;
    } else {
      $link = $this->link_test;
      $token = $this->token_test;
    }
    $curl = curl_init();
    curl_setopt_array($curl, array(
        CURLOPT_URL => $link . "/services/shipment/v2/" . $shipmentId,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
        CURLOPT_HTTPHEADER => array(
            "Token: " . $token,
            "X-Client-Source: S22993698",
        ),
    ));
    $response = curl_exec($curl);
    curl_close($curl);
    return $response;
  }
  // In đơn hàng
  function get_shipping_label($trackingOrder,$live) {
    if($live) {
      $link = $this->link_live;
      $token = $this->token_live;
    } else {
      $link = $this->link_test;
      $token = $this->token_test;
    }
    $curl = curl_init();
    curl_setopt_array($curl, array(
        CURLOPT_URL => $link . "/services/label/" . $trackingOrder,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
        CURLOPT_HTTPHEADER => array(
            "Token: " . $token,
            "X-Client-Source: S22993698",
        ),
    ));
    $response = curl_exec($curl);
    curl_close($curl);
    return $response;
  }
  // hủy đơn hàng
  function cancel_shipment($trackingOrder, $live) {
    if($live) {
      $link = $this->link_live;
      $token = $this->token_live;
    } else {
      $link = $this->link_test;
      $token = $this->token_test;
    }
    $curl = curl_init();
    curl_setopt_array($curl, array(
        CURLOPT_URL => $link . "/services/shipment/cancel/" . $trackingOrder,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
        CURLOPT_CUSTOMREQUEST => "POST", // Phương thức POST
        CURLOPT_HTTPHEADER => array(
            "Token: " . $token,
            "X-Client-Source: S22993698",
        ),
    ));
    $response = curl_exec($curl);
    curl_close($curl);
    return $response;
  }
  // tạo đơn hàng
  function tao_donhang($orderData, $live) {
    //$order = '{"products":[{"name":"bút","weight":0.1,"quantity":1,"product_code":"23304A3MHLMVMXX625"},{"name":"tẩy","weight":0.2,"quantity":1,"product_code":""}],"order":{"id":"a4","pick_name":"HCM-nội thành","pick_address":"590 CMT8 P.11","pick_province":"TP. Hồ Chí Minh","pick_district":"Quận 3","pick_ward":"Phường 1","pick_tel":"0911222333","tel":"0911222333","name":"GHTK - HCM - Noi Thanh","address":"123 nguyễn chí thanh","province":"TP. Hồ Chí Minh","district":"Quận 1","ward":"Phường Bến Nghé","hamlet":"Khác","is_freeship":"1","pick_date":"2016-09-30","pick_money":47000,"note":"Khối lượng tính cước tối đa: 1.00 kg","value":3000000,"transport":"fly","pick_option":"cod","pick_session":2,"tags":[1]}}';
    if($live) {
      $link = $this->link_live;
      $token = $this->token_live;
    } else {
      $link = $this->link_test;
      $token = $this->token_test;
    }
    $curl = curl_init();
    curl_setopt_array($curl, array(
        CURLOPT_URL => $link . "/services/shipment/order",
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
        CURLOPT_CUSTOMREQUEST => "POST",
        CURLOPT_POSTFIELDS => $orderData,
        CURLOPT_HTTPHEADER => array(
            "Content-Type: application/json",
            "Token: " . $token,
            "X-Client-Source: S22993698",
            "Content-Length: " . strlen($orderData),
        ),
    ));
    $response = curl_exec($curl);
    curl_close($curl);
    return $response;
  }
  // Lấy danh sách điểm lấy hàng
  function get_pickup_addresses($live) {
    if($live) {
      $link = $this->link_live;
      $token = $this->token_live;
    } else {
      $link = $this->link_test;
      $token = $this->token_test;
    }
    $curl = curl_init();
    curl_setopt_array($curl, array(
        CURLOPT_URL => $link . "/services/shipment/list_pick_add",
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => "GET",
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
        CURLOPT_HTTPHEADER => array(
            "Token: " . $token,
            "X-Client-Source: S22993698",
        ),
    ));
    $response = curl_exec($curl);
    curl_close($curl);
    return $response;
  }
  // Lấy danh sách địa chỉ
  function get_address_level4($data, $live) {
    //   $data = array(
    //     "province" => "Hà nội",
    //     "district" => "Quận Ba Đình",
    //     "ward_street" => "Đội Cấn",
    //     "address" => "",
    // );
    if($live) {
      $link = $this->link_live;
      $token = $this->token_live;
    } else {
      $link = $this->link_test;
      $token = $this->token_test;
    }
    $curl = curl_init();
    curl_setopt_array($curl, array(
        CURLOPT_URL => $link . "/services/address/getAddressLevel4?" . http_build_query($data),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
        CURLOPT_HTTPHEADER => array(
            "Token: " . $token,
            "X-Client-Source: S22993698",
        ),
    ));
    $response = curl_exec($curl);
    curl_close($curl);
    return $response;
  }
  // Tính phí ship GHTK theo bảng giá
  function get_tax($can_nang, $tien_hang, $tinh_gui, $mien_gui, $tinh_nhan, $mien_nhan, $cod = false, $giao_lai = false) {
    // Kiểm tra nội miền hay liên miền
    $is_noi_mien = ($tinh_gui == $tinh_nhan || $mien_gui == $mien_nhan);
    
    // Tính phí ship cơ bản theo trọng lượng (gram)
    // Cột 1: Nội miền, Cột 2: Liên miền
    if ($can_nang <= 500) { // 0-0.5kg
      $phi_ship = $is_noi_mien ? 21000 : 21000;
    } else if ($can_nang <= 1000) { // 0.5-1kg  
      $phi_ship = $is_noi_mien ? 21000 : 21000;
    } else if ($can_nang <= 2000) { // 1-2kg
      $phi_ship = $is_noi_mien ? 23000 : 23000;
    } else if ($can_nang <= 3000) { // 2-3kg
      $phi_ship = $is_noi_mien ? 27000 : 27000;
    } else if ($can_nang <= 4000) { // 3-4kg
      $phi_ship = $is_noi_mien ? 32000 : 32000;
    } else if ($can_nang <= 5000) { // 4-5kg
      $phi_ship = $is_noi_mien ? 37000 : 37000;
    } else if ($can_nang <= 6000) { // 5-6kg
      $phi_ship = $is_noi_mien ? 44000 : 47000;
    } else if ($can_nang <= 7000) { // 6-7kg
      $phi_ship = $is_noi_mien ? 51000 : 57000;
    } else if ($can_nang <= 8000) { // 7-8kg
      $phi_ship = $is_noi_mien ? 58000 : 67000;
    } else if ($can_nang <= 10000) { // 8-10kg (bao gồm cả 9-10kg)
      $phi_ship = $is_noi_mien ? 58000 : 67000;
    } else { // >10kg
      $can_vuot = ceil(($can_nang - 10000) / 1000);
      $phi_co_ban = $is_noi_mien ? 58000 : 67000; // Phí cơ bản 10kg
      $phi_vuot_kg = $is_noi_mien ? 7000 : 10000; // +7k/kg nội miền, +10k/kg liên miền
      $phi_ship = $phi_co_ban + ($can_vuot * $phi_vuot_kg);
    }
    
    // Phí thu hộ COD
    $phi_cod = 0;
    if ($cod) {
      $phi_cod = $is_noi_mien ? 50000 : 60000; // 50k nội miền, 60k liên miền
    }
    
    // Phí giao lại
    $phi_giao_lai = 0;
    if ($giao_lai) {
      $kg_giao_lai = ceil($can_nang / 1000);
      $phi_giao_lai = $is_noi_mien ? ($kg_giao_lai * 5000) : ($kg_giao_lai * 6000); // +5k/kg nội miền, +6k/kg liên miền
    }
    
    // Phí bảo hiểm (miễn phí theo bảng giá)
    $phi_baohiem = 0;
    
    // Phí hoàn
    $phi_hoan = 10000;
    
    // Tổng phí
    $phi_tong = $phi_ship + $phi_cod + $phi_giao_lai + $phi_baohiem;
    
    $info = array(
      'phi_ship' => $phi_ship,
      'phi_cod' => $phi_cod,
      'phi_giao_lai' => $phi_giao_lai,
      'phi_baohiem' => $phi_baohiem,
      'phi_hoan' => $phi_hoan,
      'phi_tong' => $phi_tong,
      'is_noi_mien' => $is_noi_mien
    );
    
    return json_encode($info);
  }
}
?>