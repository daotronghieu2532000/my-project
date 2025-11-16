# API Endpoints cho Product Reviews

## Base URL
```
https://api.socdo.vn/v1/product_reviews
```

## 1. Lấy danh sách đánh giá sản phẩm

### GET Request
```
GET https://api.socdo.vn/v1/product_reviews?product_id=4258&page=1&limit=20
```

### Query Parameters
- `product_id` (required): ID sản phẩm
- `page` (optional): Số trang (mặc định: 1)
- `limit` (optional): Số lượng mỗi trang (mặc định: 20, tối đa: 100)
- `rating` (optional): Lọc theo số sao (1-5, 0 = tất cả)
- `sort` (optional): Sắp xếp (`latest`, `oldest`, `highest`, `lowest`)
- `variant_id` (optional): Lọc theo biến thể

### Response Example
```json
{
  "success": true,
  "message": "Lấy danh sách đánh giá thành công",
  "data": {
    "reviews": [
      {
        "id": 18,
        "product_id": 4258,
        "variant_id": null,
        "product_name": "Máy nướng kẹp bánh mì 3 in 1 Elmich SME-8578 2 màu lựa chọn",
        "product_image": "/uploads/minh-hoa/may-nuong-kep-banh-mi-3-in-1-elmich-2-mau-lua-chon-1754297755.jpg",
        "variant": {
          "id": null,
          "name": "Be",
          "full_name": "Máy nướng kẹp bánh mì 3 in 1 Elmich SME-8578 2 màu lựa chọn - Be",
          "image": "https://socdo.cdn.vccloud.vn/uploads/minh-hoa/may-nuong-kep-banh-mi-3-in-1-elmich-2-mau-lua-chon-1754297755.jpg",
          "color": "",
          "size": ""
        },
        "user_id": 8050,
        "shop_id": 20755,
        "content": "quá ok",
        "rating": 5,
        "images": [
          "https://socdo.vn/uploads/comments/comment_8050_1763274697_1234.jpg"
        ],
        "is_verified_purchase": true,
        "order_id": 18520,
        "likes_count": 0,
        "dislikes_count": 0,
        "created_at": "2025-11-16 13:31:37",
        "created_at_formatted": "16/11/2025 13:31",
        "is_pinned": false,
        "user_name": "Trọng Hiếu 2❤️",
        "user_avatar": "https://socdo.vn/uploads/avatar/u8050_1234567890.jpg"
      }
    ],
    "pagination": {
      "current_page": 1,
      "total_pages": 1,
      "total_reviews": 1,
      "limit": 20,
      "has_next": false,
      "has_prev": false
    }
  }
}
```

## 2. Lấy lịch sử đánh giá của user

### GET Request
```
GET https://api.socdo.vn/v1/product_reviews?user_id=8050&page=1&limit=20&status=all
```

### Query Parameters
- `user_id` (required): ID người dùng
- `page` (optional): Số trang (mặc định: 1)
- `limit` (optional): Số lượng mỗi trang (mặc định: 20)
- `status` (optional): Lọc theo trạng thái (`all`, `reviewed`, `pending`)

### Response Example
```json
{
  "success": true,
  "message": "Lấy lịch sử đánh giá thành công",
  "data": {
    "reviews": [
      {
        "order_id": 18520,
        "ma_don": "DH251116133040740_20755",
        "date_post": 1763274640,
        "date_post_formatted": "16/11/2025",
        "products": [
          {
            "id": 4258,
            "name": "Máy nướng kẹp bánh mì 3 in 1 Elmich SME-8578 2 màu lựa chọn - Be",
            "image": "https://socdo.cdn.vccloud.vn/uploads/minh-hoa/may-nuong-kep-banh-mi-3-in-1-elmich-2-mau-lua-chon-1754297755.jpg",
            "color": "",
            "size": "",
            "has_review": true,
            "review": {
              "id": 18,
              "content": "quá ok",
              "rating": 5,
              "images": [
                "https://socdo.vn/uploads/comments/comment_8050_1763274697_1234.jpg"
              ],
              "is_verified_purchase": true,
              "review_date": "2025-11-16 13:31:37",
              "review_date_formatted": "16/11/2025 13:31"
            }
          }
        ]
      }
    ],
    "pagination": {
      "current_page": 1,
      "total_pages": 1,
      "total_reviews": 1,
      "limit": 20,
      "has_next": false,
      "has_prev": false
    }
  }
}
```

## 3. Submit đánh giá sản phẩm

### POST Request
```
POST https://api.socdo.vn/v1/product_reviews
Content-Type: application/json
Authorization: Bearer {token}
```

### Request Body
```json
{
  "user_id": 8050,
  "product_id": 4258,
  "shop_id": 20755,
  "content": "Sản phẩm rất tốt",
  "rating": 5,
  "variant_id": null,
  "order_id": 18520,
  "images": [
    "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD..."
  ]
}
```

### Response Example
```json
{
  "success": true,
  "message": "Đánh giá thành công",
  "data": {
    "comment_id": 18,
    "product_id": 4258,
    "user_id": 8050,
    "rating": 5,
    "is_verified_purchase": 1,
    "product_name": "Máy nướng kẹp bánh mì 3 in 1 Elmich SME-8578 2 màu lựa chọn",
    "product_image": "/uploads/minh-hoa/may-nuong-kep-banh-mi-3-in-1-elmich-2-mau-lua-chon-1754297755.jpg",
    "variant_id": null,
    "variant_name": "Be",
    "variant_image": "https://socdo.cdn.vccloud.vn/uploads/minh-hoa/may-nuong-kep-banh-mi-3-in-1-elmich-2-mau-lua-chon-1754297755.jpg",
    "variant_color": "",
    "variant_size": ""
  }
}
```

## 4. Lấy thống kê đánh giá sản phẩm

### GET Request
```
GET https://api.socdo.vn/v1/product_rating_stats?product_id=4258
```

### Query Parameters
- `product_id` (required): ID sản phẩm

### Response Example
```json
{
  "success": true,
  "data": {
    "product_id": 4258,
    "total_reviews": 10,
    "average_rating": 4.5,
    "rating_5": 6,
    "rating_4": 2,
    "rating_3": 1,
    "rating_2": 1,
    "rating_1": 0
  }
}
```

## Notes

1. **Ảnh đánh giá**: Khi submit, ảnh base64 sẽ được upload và lưu vào `/uploads/comments/comment_{user_id}_{timestamp}_{random}.jpg`
2. **Biến thể**: 
   - Nếu có `order_id`, biến thể sẽ được lấy từ `donhang.sanpham`
   - Biến thể được extract từ `tieu_de` (phần sau dấu " - " cuối cùng)
   - Ví dụ: "Máy nướng... - Be" → biến thể là "Be"
3. **Thông tin sản phẩm**: Mỗi review sẽ bao gồm `product_name` và `product_image` từ bảng `sanpham`
4. **Thông tin biến thể**: Mỗi review sẽ bao gồm object `variant` với thông tin đầy đủ nếu có

