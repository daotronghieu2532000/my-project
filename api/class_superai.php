<?php
class class_superai extends class_manage {
  // Khai báo properties của class
  private $token;
  function __construct() {
      // Gán giá trị cho properties
      $this->token = '0tnojP97T3veg90tZH8O2GeoLSlxSoFsfYMFDb4K';
  }
  // Hàm gửi POST request sử dụng curl
  function curl_post($url, $data, $headers = array()) {
      $ch = curl_init($url);
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
      curl_setopt($ch, CURLOPT_POST, true);
      curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
      if (!empty($headers)) {
          curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
      } else {
          curl_setopt($ch, CURLOPT_HTTPHEADER, array(
              'Content-Type: application/json'
          ));
      }
      $result = curl_exec($ch);
      if (curl_errno($ch)) {
          $error = curl_error($ch);
          curl_close($ch);
          return false;
      }
      curl_close($ch);
      return $result;
  }

  // Hàm gửi GET request sử dụng curl
  function curl_get($url, $headers = array()) {
      $ch = curl_init($url);
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
      if (!empty($headers)) {
          curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
      }
      $result = curl_exec($ch);
      if (curl_errno($ch)) {
          $error = curl_error($ch);
          curl_close($ch);
          return false;
      }
      curl_close($ch);
      return $result;
  }
  function get_token() {
    $url = 'https://api.superai.vn/v1/platform/auth/token';
    $data = array(
        "username" => "0898998138",
        "password" => "Socdo@2025",
        "partner" => "WOsRymNkoU8tRsJwFdNZQd73M8urrlxm4NvAtIvA"
    );
    $headers = array(
        'Accept: application/json',
        'Content-Type: application/json'
    );
    $response = $this->curl_post($url, json_encode($data), $headers);
    return $response;
  }
  // lấy danh sách tỉnh
  function get_list_tinh() {
      $url = 'https://api.superai.vn/v1/platform/areas/province';
      $result = $this->curl_get($url);
      return $result;
  }
  // lấy danh sách huyện
  function get_list_huyen($province_id) {
      $url = 'https://api.superai.vn/v1/platform/areas/district?province='.$province_id;
      $result = $this->curl_get($url);
      return $result;
  }
  // lấy danh sách xã
  function get_list_xa($district_id) {
      $url = 'https://api.superai.vn/v1/platform/areas/commune?district='.$district_id;
      $result = $this->curl_get($url);
      return $result;
  }
  // Hàm gọi API tối ưu đơn hàng từ SuperAI
  function toi_uu_donhang() {
      $url = 'https://api.superai.vn/v1/platform/orders/optimization';
      $headers = array(
          'Accept: application/json',
          'Token: ' . $this->token
      );
      $result = $this->curl_get($url, $headers);
      return $result;
  }
  // Hàm lấy phí vận chuyển từ SuperAI
  //$sender_province= "Thành phố Hồ Chí Minh";
  //$sender_district= "Huyện Bình Chánh";
  //$receiver_province= "Thành phố Hà Nội";
  //$receiver_district= "Quận Tây Hồ";
  //$weight= 500;
  //$value= 12000000;
  function get_fee($sender_province, $sender_district, $receiver_province, $receiver_district, $weight, $value) {
      $url = 'https://api.superai.vn/v1/platform/orders/price';
      $headers = array(
          'Content-Type: application/json',
          'Token: ' . $this->token
      );
      $data = array(
          "sender_province" => $sender_province,
          "sender_district" => $sender_district,
          "receiver_province" => $receiver_province,
          "receiver_district" => $receiver_district,
          "weight" => $weight,
          "value" => $value
      );
      $response = $this->curl_post($url, json_encode($data), $headers);
      return $response;
  }
  // Hàm tạo đơn hàng mới qua API SuperAI (dev)
  function create_order($order_data) {
      //Nếu muốnNếu bạn muốn gửi đơn sang 1 Nhà Vận Chuyển bất kỳ thì bổ sung trường carrier với giá trị Mã Định Danh Nhà Vận Chuyển vào Request Payload.
      // Ví dụ nếu muốn gửi đơn sang Giao Hàng Nhanh (GHN) thì điền carrier: "2"
      // $order_data = array(
      //     "name" => "Quynh Anh Tran",
      //     "phone" => "0987654321",
      //     "address" => "Quán Nhậu Anh Em Mình, Đường Số 2, ấp Phú Nhơn",
      //     "province" => "Tỉnh Hậu Giang",
      //     "district" => "Châu Thành A",
      //     "commune" => "Xã Tân Phú Thạnh",
      //     "amount" => 160000,
      //     "value" => 160000,
      //     "weight" => 200,
      //     "payer" => "1",
      //     "config" => "1",
      //     "soc" => "PO854252213",
      //     "note" => "được kiểm tra váy áo không thử,không mở hộp đai latex ,mỹ phẩm,phụ kiện- chỉ được kiểm tra bên ngoài",
      //     "barter" => null,
      //     "product_type" => "2",
      //     "products" => array(
      //         array(
      //             "sku" => "Short jean co giãn tốt ống rộng wax ZR01 245 - NHẠT WAX - 28",
      //             "name" => "Short jean co giãn tốt ống rộng wax ZR01 245 - NHẠT WAX - 28",
      //             "price" => 245000,
      //             "weight" => 100,
      //             "quantity" => 1
      //         ),
      //         array(
      //             "sku" => "Quần yếm jeans mã Z 295 - NHẠT - 28",
      //             "name" => "Quần yếm jeans mã Z 295 - NHẠT - 28",
      //             "price" => 295000,
      //             "weight" => 100,
      //             "quantity" => 1
      //         )
      //     )
      // );
      $url = 'https://api.superai.vn/v1/platform/orders/create';
      $headers = array(
          'Accept: application/json',
          'Content-Type: application/json',
          'Token: ' . $this->token
      );
      // $order_data là mảng chứa thông tin đơn hàng, ví dụ như trong hướng dẫn
      $response = $this->curl_post($url, json_encode($order_data), $headers);
      return $response;
  }
  // Hàm lấy thông tin đơn hàng qua API SuperAI (dev)
  function get_order_info($type, $code) {
      $url = 'https://api.superai.vn/v1/platform/orders/info';
      $headers = array(
          'Content-Type: application/json',
          'Token: ' . $this->token
      );
      $data = array(
          'type' => $type,
          'code' => $code
      );
      $response = $this->curl_post($url, json_encode($data), $headers);
      return $response;
  }
  // Hàm lấy token in đơn hàng
  function get_order_token($codes = array()) {
      $url = 'https://api.superai.vn/v1/platform/orders/token';
      $headers = array(
          'Accept: application/ecmascript',
          'Content-Type: application/json',
          'Token: ' . $this->token
      );
      $data = array(
          'code' => $codes
      );
      $response = $this->curl_post($url, json_encode($data), $headers);
      return $response;
  }
  // Hàm lấy nhãn in đơn hàng
  function get_order_label($token, $size = 'S9') {
      $url = 'https://api.superai.vn/v1/platform/orders/label?token=' . urlencode($token) . '&size=' . urlencode($size);
      $response = $this->curl_get($url);
      return $response;
  }
  // Hàm huỷ đơn hàng qua API SuperAI (dev)
  function cancel_order($code) {
    // code chính là superai_code trả về của create_order
      $url = 'https://api.superai.vn/v1/platform/orders/cancel';
      $headers = array(
          'Accept: application/json',
          'Content-Type: application/json',
          'Token: ' . $this->token
      );
      $data = array(
          'code' => $code
      );
      $response = $this->curl_post($url, json_encode($data), $headers);
      return $response;
  }
  // Hàm lấy danh sách hãng vận chuyển qua API SuperAI (dev)
  function get_carriers_list() {
      $url = 'https://api.superai.vn/v1/platform/carriers/list';
      $headers = array(
          'Accept: application/json',
          'Token: ' . $this->token
      );
      $response = $this->curl_get($url, $headers);
      return $response;
  }
  // Hàm lấy danh sách kho qua API SuperAI (dev)
  function get_warehouses_list() {
      $url = 'https://api.superai.vn/v1/platform/warehouses';
      $headers = array(
          'Accept: application/json',
          'Token: ' . $this->token
      );
      $response = $this->curl_get($url, $headers);
      return $response;
  }
}
?>