{header}
<style>
    body {
        opacity: 0;
        transition: opacity 0.1s ease-in-out;
    }

    header {
        width: 100%;
        display: inline-block;
        z-index: 1000;
        position: fixed;
    }

    .owl-dots {
        width: 100%;
        display: none;
        justify-content: center;
        align-items: center;
        height: 40px;
    }

    .banner-container {
        width: 100%;
        max-width: 1310px;
        /* Giữ cố định 1280px */
        margin: 0 auto;
        padding: 15px;
        position: relative;
        box-sizing: border-box;
        /* Đảm bảo padding không làm vượt kích thước */
    }

    .silde_banner {
        margin: 0;
        margin-top: 110px;
    }

    .banner_wrapper {
        display: flex;
        gap: 10px;
        /* Giữ gap nhỏ như trong hình */
        /* margin-bottom: 40px; */
        width: 100%;
        /* Đảm bảo chiếm toàn bộ chiều ngang container */
    }

    .banner_index .box_top_index {
        background: none;
        border-radius: 10px;
        overflow: hidden;
        margin-bottom: -73px;
        transition: background 0.3s ease;
    }

    .banner_index .box_top_index img.loaded {
        opacity: 1;
    }

    .banner_index .box_top_index img.loaded+a {
        background: none !important;
    }

    .banner_index .owl-carousel {
        margin: 0;
        padding: 0;
        overflow: hidden;
    }

    .banner_index .owl-stage-outer {
        overflow: hidden;
    }

    .owl-carousel .owl-item img {
        display: block;
        width: 100%;
        margin-bottom: 72px;
        border-radius: 10px;
    }

    .banner_index {
        width: calc(75% - 10px);
        /* 75% của 1280px là 960px, trừ đi 3.75px (5px * 75%) để vừa khung sau khi có gap */
        position: relative;
        height: 300px;
        border-radius: 8px;
        overflow: hidden;
    }

    .banner_index img {
        width: 100%;
        height: 300px;
        /* Giảm chiều cao xuống 300px để trông cân đối như trong hình */
        object-fit: cover;
        /* Đảm bảo ảnh vừa khung, có thể bị cắt nhẹ để giữ tỷ lệ */
        border-radius: 8px;
        transition: transform 0.3s ease, opacity 0.3s ease;
        object-position: center;
        opacity: 0;
    }

    .banner_index img.loaded {
        opacity: 1;
    }

    /* .banner_index img:hover {
        transform: scale(1.02);
    } */

    .home_brand .list_brand {
        width: 100%;
        display: flex;
        gap: 10px;
        margin-top: -30px;
    }

    .list_brand_tren_duoi {
        width: calc(25%);
        /* 25% của 1280px là 320px, trừ đi 1.25px (5px * 25%) để vừa khung sau khi có gap */
        display: flex;
        flex-direction: column;
        gap: 10px;
        /* Giảm khoảng cách giữa các banner trong list_brand_tren_duoi */
        height: 300px;
        /* Đồng bộ chiều cao với banner_index */
    }

    .list_brand_tren_duoi .li_banner {
        width: 100%;
        height: calc(50% - 5px);
    }

    .list_brand_tren_duoi .li_banner a {
        display: block;
        width: 100%;
        height: 100%;
        border-radius: 8px;
        overflow: hidden;
    }

    .list_brand_tren_duoi .li_banner img {
        width: 100%;
        height: 100%;
        /* Đảm bảo ảnh lấp đầy khung */
        object-fit: cover;
        /* Đảm bảo ảnh vừa khung, có thể bị cắt nhẹ để giữ tỷ lệ */
        border-radius: 8px;
        transition: transform 0.3s ease;
        object-position: center;
    }

    /* .list_brand_tren_duoi .li_banner img:hover {
        transform: scale(1.02);
    } */

    .list_brand {
        display: flex;
        justify-content: space-between;
        gap: 15px;
    }

    .list_brand .li_banner {
        max-width: calc(100%/3 - 20px/3);
    }

    .list_brand .li_banner a {
        display: block;
        width: 100%;
        height: 120px;
        border-radius: 8px;
        overflow: hidden;
        position: relative;
    }

    .list_brand .li_banner img {
        width: 100%;
        height: 100%;
        object-fit: cover;
        border-radius: 8px;
        transition: transform 0.3s ease;
        object-position: center;
    }

    .list_brand .li_banner img:hover {
        transform: scale(1.02);
    }

    .title_box {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 15px 0;
        font-size: 20px;
        font-weight: bold;
    }

    .title_box img {
        width: 30px;
        height: 30px;
    }

    /* .home_box .container {
        max-width: 1280px;
        margin: 0 auto;
        padding: 0 15px;
    }

    .home_box .title_box {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .home_box .title_box h2 {
        font-size: 20px;
    }

    .home_box .title_box a {
        text-decoration: none;
        color: #007bff;
    } */

    .tab_box {
        display: flex;
        gap: 15px;
    }

    .box_news_left {
        width: 50%;
    }

    .box_news_right {
        width: 50%;
    }

    .list_news {
        max-height: 400px;
        overflow-y: auto;
    }

    .swiper-slide img {
        width: 100%;
        height: 100%;
        object-fit: cover;
        object-position: center;
    }

    @media (max-width: 768px) {
        .banner_index {
            width: 100%;
            position: relative;
            display: flex;
            justify-content: center;
        }

        .banner_index img {
            width: 360px;
            height: 200px;
            object-fit: cover;
            border-radius: 8px;
            display: block;
        }

        .owl-carousel .owl-item img {
            margin-bottom: 0px !important;
            width: 360px;
            height: 200px;
            object-fit: cover;
            border-radius: 8px;
        }

        .owl-dots {
            width: 100%;
            display: none;
            justify-content: center;
            align-items: center;
            height: 40px;
        }

        .owl-carousel .owl-item {
            width: 360px !important;
            margin-right: 12px;
            display: flex;
            justify-content: center;
        }

        .banner_index .box_top_index {
            background: none;
            border-radius: 8px;
            overflow: hidden;
            margin-bottom: 0;
            width: 360px;
            height: 200px;
            padding-top: 0px !important;
            padding-bottom: 0px !important;
        }

        .banner_wrapper {
            max-height: none;
            overflow: hidden;
            display: flex;
            justify-content: center;
        }

        .owl-carousel .owl-stage-outer {
            overflow: hidden;
            border-radius: 8px;
        }

        .home_brand .list_brand {
            display: none;
            /* Giữ nguyên */
        }

        .list_brand_tren_duoi {
            display: none;
            /* Giữ nguyên */
        }

        .tab_box {
            flex-direction: column;
            /* Giữ nguyên */
        }

        .box_news_left,
        .box_news_right {
            width: 100%;
            /* Giữ nguyên */
        }

        .box_action_end {
            margin-left: 5px !important;
        }
    }

    .banner_index .owl-item img {
        border-radius: 2px;
    }

    /* .thuong-hieu-slide {
        margin-left: 0px;
        display: flex !important;
        flex-wrap: nowrap !important;
    } */

    #slide_danhmuc_noibat .swiper-slide {
        border-radius: 8px;
        /* Áp dụng border-radius cho các slide */
        overflow: hidden;
        /* Đảm bảo nội dung bên trong bị cắt đúng theo border-radius */
    }

    #slide_danhmuc_noibat .swiper-slide img {
        border-radius: 8px;
        /* Áp dụng border-radius cho ảnh trong slide */
        width: 100%;
        height: 100%;
        object-fit: cover;
        /* Đảm bảo ảnh vừa khung */
    }

    .tab_box .tab .box_news_right .li_news .content_news h3,
    .tab_box .tab .box_news_right .li_news .content_news h3 a.link {
        font-weight: normal;
        line-height: 1.2;
        font-size: 20px;
        font-weight: bold;
        font-size: 16px;
    }

    .tab_box .tab .box_news_left .li_news .content_news h3,
    .tab_box .tab .box_news_left .li_news .content_news h3 a.link {
        font-weight: normal;
        line-height: 1.2;
        font-size: 16px;
        font-weight: bold;
    }

    .title_box h3 {
        height: 30px;
        line-height: 36px;
        margin-left: 10px;
        font-size: 18px;
        font-weight: bold;
        text-align: start;
        color: #144e8d;
        background-size: cover;
    }

    .home_box .title_box h2 {
        font-size: 18px;
    }

    .box_danhmuc_noibat .container .title_box {
        font-size: 18px;
    }
</style>
<script>
    document.addEventListener("DOMContentLoaded", function () {
        document.body.style.opacity = "1";

        // Preload tất cả ảnh banner
        var bannerImgs = document.querySelectorAll('.banner_index img');
        bannerImgs.forEach(function (img) {
            if (img.dataset.src) {
                var preloadImg = new Image();
                preloadImg.onload = function () {
                    img.src = img.dataset.src;
                    img.classList.add('loaded');
                    img.style.opacity = '1';
                    if (img.parentElement) {
                        img.parentElement.style.background = 'none';
                    }
                };
                preloadImg.onerror = function () {
                    img.style.display = 'none';
                    img.classList.add('loaded');
                    if (img.parentElement) {
                        img.parentElement.style.background = '#f0f0f0';
                    }
                };
                preloadImg.src = img.dataset.src;
            }
        });
    });
</script>

<body class="body_scroll">
    {box_header}
    <div class="mobile_brand">
        <div class="mobile_brand_container">
            <!-- Swiper -->
            <div class="swiper-container" id="mobile_brand_swiper">
                <div class="swiper-wrapper">
                    {banner_mobile}
                </div>
                <script>
                    document.addEventListener("DOMContentLoaded", function () {
                        var swiper = new Swiper('#mobile_brand_swiper', {
                            slidesPerView: 1,
                            spaceBetween: 10,
                            loop: false,
                            autoplay: {
                                delay: 3000,
                                disableOnInteraction: false,
                            },
                            pagination: {
                                el: '.swiper-pagination',
                                clickable: true,
                            },
                        });
                    });
                </script>
            </div>
        </div>
    </div>
    <div class="home_brand">
        <div class="banner-container">
            <div class="silde_banner">
                <div class="banner_wrapper">
                    <div class="banner_index">
                        <div class="owl-carousel">
                            {banner_index}
                        </div>
                    </div>
                    <div class="list_brand_tren_duoi">
                        {banner_doitac_hai}
                    </div>
                </div>
            </div>
            <!-- <div class="list_brand">
                {banner_big}
            </div> -->
        </div>
    </div>
    <div class="box_danhmuc_noibat">
        <style>
            .box_action_end {
                display: flex;
                gap: 10px;
                margin-left: 700px;
            }

            .action_item {
                font-size: 13px;
                text-transform: none;
            }

            .gop {
                color: red;
            }

            .chung {
                color: rgb(0, 122, 223);
            }
        </style>
        <div class="container">
            <div class="title_box" style="--background: url('{bg_box_noibat}') font-size: 18px;">
                <img src="{icon_box_noibat}" alt=""> Danh mục sản phẩm
                <!--
                <div class="box_action_end">
                    <div class="action_item gop" style="--background: url('{bg_box_noibat}')">
                        Siêu gộp đơn
                    </div>
                    <div class="action_item chung" style="--background: url('{bg_box_noibat}')">
                        Mua chung
                    </div>
                </div>
                -->
            </div>
            <div class="list_danhmuc">
                {list_danhmuc_noibat}
            </div>
            <div class="action_danhmuc">
                <button class="btn_xemthem active"><i class="fa fa-chevron-down"></i> Xem thêm danh mục</button>
                <button class="btn_xemthem_xong"><i class="fa fa-chevron-up"></i> Thu nhỏ danh mục</button>
            </div>
        </div>
    </div>
    <script>
        $(document).ready(function () {
            $('.action_danhmuc').click(function () {
                $('.box_danhmuc_noibat .list_danhmuc').toggleClass('active');
                $('.action_danhmuc .btn_xemthem').toggleClass('active');
                $('.action_danhmuc .btn_xemthem_xong').toggleClass('active');
                // Scroll mượt đến vị trí của nút bấm
                setTimeout(function () {
                    $('html, body').animate({
                        scrollTop: $('.box_danhmuc_noibat').offset().top - 120
                    }, 500); // 500ms = thời gian cuộn
                }, 100);
            });
        });
    </script>
    <script>
        $(document).ready(function () {
            if ($(window).width() < 768) {
                sl = 1;
                sl_nb = 3;
            } else {
                sl = 2;
                sl_nb = 10;
            }

            var $carousel = $('.banner_index .owl-carousel');
            var slideCount = $carousel.find('.box_top_index').length;

            $carousel.owlCarousel({
                items: 1,
                loop: slideCount > 1, // Only loop if there are multiple slides
                nav: slideCount > 1, // Show navigation only if multiple slides
                dots: true, // Show dots for better UX
                autoplay: slideCount > 1, // Autoplay only if multiple slides
                autoplayTimeout: 4000,
                autoplayHoverPause: true,
                margin: 12,
                stagePadding: 0,
                autoHeight: false, // Prevent height issues
                navText: [
                    '<i class="mdi mdi-chevron-left"></i>',
                    '<i class="mdi mdi-chevron-right"></i>'
                ],
                responsive: {
                    0: {
                        nav: false, // Hide nav on mobile
                        dots: true
                    },
                    768: {
                        nav: slideCount > 1
                    }
                }
            });

            // var slide_danhmuc_noibat = new Swiper('#slide_danhmuc_noibat', {
            //     direction: 'horizontal',
            //     slidesPerView: sl_nb,
            //     slidesPerColumn: 2,
            //     slidesPerColumnFill: 'column',
            //     spaceBetween: 0,
            //     loop: false,
            //     observer: true,
            //     observeParents: true,
            //     autoplay: { delay: 3000 }
            // });
            // $('.box_danhmuc_noibat').show();
        });
    </script>
    <div class="list_branddoitac">
        {banner_doitac}
    </div>
    <style>
        .list_branddoitac {
            display: flex;
            justify-content: space-between;
            gap: 10px;
            margin: auto;
            margin-top: 10px;
            max-width: 1310px;
            padding: 0 15px;
            box-sizing: border-box;
        }

        .list_branddoitac .li_banner {
            flex: 1;
            max-width: calc(100%/3 - 20px/3);
        }

        .list_branddoitac .li_banner a {
            display: block;
            width: 100%;
            height: 145px;
            border-radius: 8px;
            overflow: hidden;
            position: relative;
        }
        .list_branddoitac .li_banner img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            border-radius: 8px;
            transition: transform 0.3s ease;
            object-position: center;
        }

        .list_branddoitac .li_banner img:hover {
            transform: scale(1.02);
        }

        /* Thêm responsive */
        @media (max-width: 768px) {
            .list_branddoitac {
                flex-direction: column;
                gap: 15px;
            }
            .list_branddoitac .li_banner img{
                object-fit: fill !important;
            }
            .list_branddoitac .li_banner {
                max-width: 100%;
            }

            .list_branddoitac .li_banner a {
                height: 145px;
            }
        }
        
        .giam {
            position: absolute;
            top: -2px;
            right: -1px;
            background: linear-gradient(135deg, #ff7f00, #ff5500);
            color: white;
            font-weight: bold;
            font-size: 12px;
            padding: 5px 10px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0, 0, 0, 0.2);
            z-index: 10;
        }
    </style>
    {box_flash_sale_sand}
    <script>
        function handleMobileSlides() {
            const isMobile = window.innerWidth < 768;
            const slides = document.querySelectorAll('.list_branddoitac .li_banner');
            let swiper;

            if (isMobile) {
                // Tạo container cho slider
                const sliderContainer = document.createElement('div');
                sliderContainer.className = 'swiper-container';
                sliderContainer.style.width = '100%';
                sliderContainer.style.overflow = 'hidden';
                sliderContainer.style.position = 'relative';

                // Lấy phần tử cha của slides
                const parentElement = slides[0].parentElement;

                // Tạo wrapper cho slides
                const wrapper = document.createElement('div');
                wrapper.className = 'swiper-wrapper';
                wrapper.style.display = 'flex';
                wrapper.style.transition = 'transform 0.3s ease';

                // Thêm container vào trước khi di chuyển slides
                parentElement.appendChild(sliderContainer);
                sliderContainer.appendChild(wrapper);

                // Di chuyển tất cả slides vào wrapper
                slides.forEach(slide => {
                    slide.style.display = 'block'; // Hiển thị tất cả slides
                    slide.className += ' swiper-slide';
                    slide.style.flex = '0 0 100%';
                    slide.style.width = '100%';
                    wrapper.appendChild(slide);
                });

                // Thêm pagination
                const pagination = document.createElement('div');
                pagination.className = 'swiper-pagination';
                sliderContainer.appendChild(pagination);

                // Thêm các nút điều hướng
                const prevButton = document.createElement('div');
                prevButton.className = 'swiper-button-prev';
                prevButton.style.left = '10px';
                prevButton.style.top = '70%';

                const nextButton = document.createElement('div');
                nextButton.className = 'swiper-button-next';
                nextButton.style.right = '10px';
                nextButton.style.top = '70%';

                sliderContainer.appendChild(prevButton);
                sliderContainer.appendChild(nextButton);

                // Thêm CSS cho nút điều hướng
                const style = document.createElement('style');
                style.textContent = `
                .swiper-button-prev, .swiper-button-next {
                    position: absolute;
                    transform: translateY(-50%);
                    z-index: 10;
                    cursor: pointer;
                    color: #fff;
                    background: rgba(0,0,0,0.5);
                    padding: 10px;
                    border-radius: 50%;
                }
                .swiper-pagination {
                    position: absolute;
                    bottom: 10px;
                    left: 0;
                    right: 0;
                    z-index: 10;
                    text-align: center;
                }
            `;
                document.head.appendChild(style);

                // Khởi tạo Swiper
                swiper = new Swiper(sliderContainer, {
                    direction: 'horizontal',
                    loop: true,
                    slidesPerView: 1,
                    spaceBetween: 0,
                    centeredSlides: true,
                    autoplay: {
                        delay: 3000,
                        disableOnInteraction: false
                    },
                    pagination: {
                        el: '.swiper-pagination',
                        clickable: true
                    },
                    navigation: {
                        nextEl: '.swiper-button-next',
                        prevEl: '.swiper-button-prev'
                    },
                    touchRatio: 1,
                    touchAngle: 45,
                    grabCursor: true
                });

                // Lazy load function
                function lazyLoadSlides() {
                    if (!swiper) return;

                    const activeSlide = swiper.slides[swiper.activeIndex];
                    if (!activeSlide) return;

                    const img = activeSlide.querySelector('.lazy-image');
                    if (img && !img.src && img.dataset.src) {
                        img.src = img.dataset.src;
                        img.onload = () => img.classList.add('loaded');
                    }
                }

                // Add event listeners for lazy loading
                if (swiper) {
                    swiper.on('init', lazyLoadSlides);
                    swiper.on('slideChange', lazyLoadSlides);
                }
            } else {
                // Trên desktop hiển thị tất cả slides
                slides.forEach(slide => {
                    slide.style.display = 'block';
                });
            }
        }

        // Chạy khi trang load xong
        document.addEventListener('DOMContentLoaded', handleMobileSlides);
        // Chạy lại khi resize window
        window.addEventListener('resize', handleMobileSlides);
    </script>
    <div class="box_thuonghieu_noibat">
        <div class="container">
            <div class="title_box" style="--background: url('{bg_box_noibat}')">
                <img src="uploads/img-icon/sirdsotimiddtrsnrr20220328211053thuonghieu.png" alt="" width="30"
                    height="30">
                <h3>THƯƠNG HIỆU NỔI BẬT</h3>
            </div>
            <div class="list_thuonghieu_noibat_wrapper">
                <div class="list_thuonghieu_noibat swiper-container" id="slide_thuonghieu">
                    <div class="swiper-wrapper">
                        {list_cac_thuong_hieu}
                    </div>
                </div>
            </div>
            <script>
                var swiper_thuonghieu;

                function getSlidesPerView() {
                    var width = $(window).width();
                    if (width < 576) {
                        return 3; // Extra small devices (phones)
                    } else if (width < 768) {
                        return 4; // Small devices (tablets)
                    } else if (width < 992) {
                        return 6; // Medium devices
                    } else {
                        return 7; // Large and Extra large devices
                    }
                }

                $(document).ready(function () {
                    swiper_thuonghieu = new Swiper('#slide_thuonghieu', {
                        slidesPerView: getSlidesPerView(),
                        spaceBetween: 10,
                        loop: true,
                        autoplay: {
                            delay: 3000,
                            disableOnInteraction: false,
                        },
                        navigation: {
                            nextEl: '.swiper-button-next',
                            prevEl: '.swiper-button-prev',
                        },
                        pagination: {
                            el: '.swiper-pagination',
                            clickable: true,
                        },
                    });
                });

                // Xử lý khi window resize
                $(window).resize(function () {
                    if (swiper_thuonghieu) {
                        swiper_thuonghieu.params.slidesPerView = getSlidesPerView();
                        swiper_thuonghieu.update();
                    }
                });
            </script>

        </div>
    </div>
    <script src="/carousel/owl.carousel.min.js"></script>
    <script type="text/javascript">
        $(document).ready(function () {
            if ($(window).width() < 768) {
                sl = 1;
                sl_nb = 3;
            } else {
                sl = 2;
                sl_nb = 10;
            }
            var slide_danhmuc_noibat = new Swiper('#slide_danhmuc_noibat', {
                direction: 'horizontal',
                slidesPerView: sl_nb,
                slidesPerColumn: 2,
                slidesPerColumnFill: 'column',
                spaceBetween: 0,
                loop: false,
                observer: true,
                observeParents: true,
                autoplay: { delay: 3000 }
            });
            $('.box_danhmuc_noibat').show();

            $('.banner_index .owl-carousel').owlCarousel({
                items: 1,
                loop: true,
                nav: true,
                dots: true,
                autoplay: true,
                autoplayTimeout: 5000,
                autoplayHoverPause: true,
                lazyLoad: true,
                lazyLoadEager: 2,
                navText: [
                    '<i class="mdi mdi-chevron-left"></i>',
                    '<i class="mdi mdi-chevron-right"></i>'
                ],
                responsive: {
                    0: { nav: false },
                    768: { nav: true }
                },
                onInitialized: function () {
                    // Tải ngay ảnh đầu tiên
                    var $firstImg = $('.banner_index .owl-item.active img');
                    if ($firstImg.length && $firstImg.hasClass('owl-lazy')) {
                        $firstImg.attr('src', $firstImg.data('src'));
                        $firstImg.addClass('loaded');
                        $firstImg[0].style.opacity = '1';
                        $firstImg[0].parentElement.style.background = 'none';
                    }

                    // Preload tất cả ảnh còn lại
                    $('.banner_index .owl-item img.owl-lazy').each(function () {
                        var $img = $(this);
                        if ($img.data('src')) {
                            var preloadImg = new Image();
                            preloadImg.onload = function () {
                                $img.attr('src', $img.data('src'));
                                $img.addClass('loaded');
                                $img[0].style.opacity = '1';
                                if ($img[0].parentElement) {
                                    $img[0].parentElement.style.background = 'none';
                                }
                            };
                            preloadImg.onerror = function () {
                                $img[0].style.display = 'none';
                                $img.addClass('loaded');
                                if ($img[0].parentElement) {
                                    $img[0].parentElement.style.background = '#f0f0f0';
                                }
                            };
                            preloadImg.src = $img.data('src');
                        }
                    });
                },
                onChanged: function (event) {
                    // Tải ảnh cho slide hiện tại ngay lập tức
                    var $activeImg = $('.banner_index .owl-item.active img');
                    if ($activeImg.length && $activeImg.hasClass('owl-lazy')) {
                        $activeImg.attr('src', $activeImg.data('src'));
                        $activeImg.addClass('loaded');
                        $activeImg[0].style.opacity = '1';
                        $activeImg[0].parentElement.style.background = 'none';
                    }
                }
            });

            var slide_brand_top_doitac = new Swiper('.slide_brand_top_doitac', {
                direction: 'vertical',
                slidesPerView: 1,
                spaceBetween: 10,
                loop: true,
                observer: true,
                observeParents: true,
                autoplay: { delay: 5000 },
                navigation: {
                    nextEl: '.slide_brand_top_doitac .next',
                    prevEl: '.slide_brand_top_doitac .prev'
                },
                breakpoints: {
                    320: {
                        direction: 'horizontal',
                        slidesPerView: 1
                    },
                    768: {
                        direction: 'vertical',
                        slidesPerView: 1
                    }
                }
            });

            var slide_brand_top_doitac_2 = new Swiper('.slide_brand_top_doitac_2', {
                direction: 'vertical',
                slidesPerView: 1,
                spaceBetween: 10,
                loop: true,
                observer: true,
                observeParents: true,
                autoplay: { delay: 5000 },
                navigation: {
                    nextEl: '.slide_brand_top_doitac_2 .next',
                    prevEl: '.slide_brand_top_doitac_2 .prev'
                },
                breakpoints: {
                    320: {
                        direction: 'horizontal',
                        slidesPerView: 1
                    },
                    768: {
                        direction: 'vertical',
                        slidesPerView: 1
                    }
                }
            });

            var slide_brand_top_doitac_3 = new Swiper('.slide_brand_top_doitac_3', {
                direction: 'vertical',
                slidesPerView: 1,
                spaceBetween: 10,
                loop: true,
                observer: true,
                observeParents: true,
                autoplay: { delay: 5000 },
                navigation: {
                    nextEl: '.slide_brand_top_doitac_3 .next',
                    prevEl: '.slide_brand_top_doitac_3 .prev'
                },
                breakpoints: {
                    320: {
                        direction: 'horizontal',
                        slidesPerView: 1
                    },
                    768: {
                        direction: 'vertical',
                        slidesPerView: 1
                    }
                }
            });
        });
    </script>
    {box_goiy}
    <!-- <div class="home_box" style="margin-top: 10px;">
        <div class="container">
            <div class="title_box" style="border-radius: 5px 5px 0px 0px;">
                <h1>BIỂU ĐỒ XÚC TIẾN THƯƠNG MẠI </h1>
                <a href="#" class="more_right">Xem chi tiết</a>
            </div>

            <canvas id="bieuDoXucTien"></canvas>


            <style>
                .xttm-title {
                    text-align: center;
                    font-size: 20px;
                    font-weight: 600;
                    margin-bottom: 10px;
                    margin-top: 0;
                }

                /* Bảng */
                .xttm-table {
                    width: 100%;
                    border-collapse: collapse;
                    background: #fff;
                    margin-bottom: 20px;
                }

                .xttm-table th,
                .xttm-table td {
                    border-bottom: 1px solid #e0e0e0;
                    padding: 0px 3px;
                    font-size: 15px;
                    text-align: center;
                    background: #fff;
                }

                .xttm-table th {
                    background: #f8f8f8;
                    font-weight: 600;
                }

                .xttm-table .xttm-guide {
                    text-align: left;
                    color: #888;
                    font-size: 14px;
                    background: #fafafa;
                }

                .xttm-table .xttm-img {
                    text-align: center;
                }

                @media (max-width: 700px) {
                    .xttm-slider-list {
                        gap: 6px;
                    }

                    .xttm-slider-item {
                        width: 70px;
                        height: 60px;
                    }

                    .xttm-slider-item1 {
                        width: 70px;
                        height: 60px;
                    }

                    .xttm-title {
                        font-size: 16px;
                    }

                    .xttm-table th,
                    .xttm-table td {
                        font-size: 13px;
                        padding: 5px;
                    }
                }

                .xttm-slider-item1.logo-container {
                    background-color: #ffffff;
                    /* Nền trắng để logo nổi bật */
                    padding: 10px;
                    /* Tạo khoảng trống giữa logo và viền */

                    /* Thêm viền xám nhẹ nhàng */
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }

                /* Áp dụng cho thẻ img nằm bên trong */
                .xttm-slider-item1.logo-container img {
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                    /* <-- Thuộc tính quan trọng nhất đây */
                    border-radius: 0;
                    /* Bỏ bo góc của riêng ảnh để trông tự nhiên */
                }

                .xttm-slider-item1 {
                    width: 120px;
                    height: 90px;
                    background: #ededed;
                    border-radius: 16px;
                    border: none;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0;
                    box-shadow: 1px 0 0 #e0e0e0;
                }

                .xttm-slider-item1:last-child {
                    border-radius: 16px;
                    box-shadow: none;
                }
            </style>

            <div class="table-header" style="margin-top: 10px;">
                <div class="xttm-title">BẢN TIN XÚC TIẾN THƯƠNG MẠI </div>
            </div>
            <div class="pagination-controls" style="display: flex;justify-content: flex-end;    margin-right: 10px;
                    margin-top: -28px;margin-bottom: 10px;">
                <span class="pagination-info" style="margin-right: 3px;">1–10 trong số 557</span>
                <button class="pagination-arrow" title="Trang trước" style="margin-right: 3px;">
                    <i class="fa fa-chevron-left"></i></button>
                <button class="pagination-arrow" title="Trang sau">
                    <i class="fa fa-chevron-right"></i>
                </button>
            </div> -->
    <!-- Table -->
    <!-- <table class="xttm-table">
                <thead>
                    <tr>
                        <th>STT</th>
                        <th>Hình ảnh</th>
                        <th>Tên doanh nghiệp</th>
                        <th>Tiêu đề</th>
                        <th>Giá trị xúc tiến</th>
                        <th>Hạn xúc tiến</th>
                        <th>Thời gian </th>
                        <th>Kết thúc</th>
                        <th>Hành động</th>
                    </tr>
                </thead>
                <tbody>
                    <tr data-id="1">
                        <td>1</td>
                        <td>
                            <div class="xttm-slider-item1 logo-container">
                                <img src="/uploads/thuong-hieu/aqua-1750816984.jpg" alt="" />
                            </div>
                        </td>
                        <td>Công ty TNHH Toàn Cầu Xanh</td>
                        <td>Hội nhập kinh tế quốc tế</td>
                        <td>1,000,000 - 2,000,000 Tỷ đ</td>
                        <td>01/01/2025</td>
                        <td>7 ngày</td>
                        <td>31/12/2025</td>
                        <td>
                            <div
                                style="display: flex; flex-wrap: nowrap; gap: 6px; justify-content: center; align-items: center;">
                                <a class="xttm-action-btn xttm-detail-btn" href="/ncc/view-xttm-detail">
                                    <span><i class="icofont-eye-open"></i> </span>
                                </a>


                            </div>
                        </td>
                    </tr>
                    <tr data-id="2">
                        <td>2</td>
                        <td>
                            <div class="xttm-slider-item1 logo-container">
                                <img src="/uploads/thuong-hieu/andbon-1750816945.jpg" alt="" />
                            </div>
                        </td>
                        <td>Công ty CP Nông Sản Việt</td>
                        <td>Xuất khẩu nông sản 2024</td>
                        <td>500,000 - 1,200,000 Tỷ đ</td>
                        <td>15/02/2025</td>
                        <td>30 ngày</td>
                        <td>17/11/2025</td>
                        <td>
                            <div
                                style="display: flex; flex-wrap: nowrap; gap: 6px; justify-content: center; align-items: center;">
                                <a class="xttm-action-btn xttm-detail-btn" href="/ncc/view-xttm-detail">
                                    <span><i class="icofont-eye-open"></i> </span>
                                </a>

                            </div>
                        </td>
                    </tr>
                    <tr data-id="3">
                        <td>3</td>
                        <td>
                            <div class="xttm-slider-item1 logo-container">
                                <img src="/uploads/thuong-hieu/tan-a-dai-thanh-1750816685.jpg" alt="" />
                            </div>
                        </td>
                        <td>Tập đoàn Thương Mại Hà Nội</td>
                        <td>Hội chợ thương mại Hà Nội</td>
                        <td>200,000 - 800,000 Tỷ đ</td>
                        <td>10/03/2025</td>
                        <td>15 ngày</td>
                        <td>25/12/2025</td>
                        <td>
                            <div
                                style="display: flex; flex-wrap: nowrap; gap: 6px; justify-content: center; align-items: center;">
                                <a class="xttm-action-btn xttm-detail-btn" href="/ncc/view-xttm-detail">
                                    <span><i class="icofont-eye-open"></i> </span>
                                </a>

                            </div>
                        </td>
                    </tr>
                    <tr data-id="4">
                        <td>4</td>
                        <td>
                            <div class="xttm-slider-item1 logo-container">
                                <img src="/uploads/thuong-hieu/chilux-1750816580.png" alt="" />
                            </div>
                        </td>
                        <td>Công ty TNHH Miền Trung Phát</td>
                        <td>Chương trình xúc tiến miền Trung</td>
                        <td>300,000 - 900,000 Tỷ đ</td>
                        <td>05/04/2025</td>
                        <td>20 ngày</td>
                        <td>25/09/2025</td>
                        <td>
                            <div
                                style="display: flex; flex-wrap: nowrap; gap: 6px; justify-content: center; align-items: center;">
                                <a class="xttm-action-btn xttm-detail-btn" href="/ncc/view-xttm-detail">
                                    <span><i class="icofont-eye-open"></i> </span>
                                </a>

                            </div>
                        </td>
                    </tr>
                    <tr data-id="5">
                        <td>5</td>
                        <td>
                            <div class="xttm-slider-item1 logo-container">
                                <img src="/uploads/thuong-hieu/akitech-1750816894.jpg" alt="" />
                            </div>
                        </td>
                        <td>Tập đoàn Đầu Tư Việt Á</td>
                        <td>Hội nghị xúc tiến đầu tư</td>
                        <td>2,000,000 - 3,000,000 Tỷ đ</td>
                        <td>20/05/2025</td>
                        <td>10 ngày</td>
                        <td>30/08/2025</td>
                        <td>
                            <div
                                style="display: flex; flex-wrap: nowrap; gap: 6px; justify-content: center; align-items: center;">
                                <a class="xttm-action-btn xttm-detail-btn" href="/ncc/view-xttm-detail">
                                    <span><i class="icofont-eye-open"></i> </span>
                                </a>

                            </div>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>

    </div> -->
    <div class="home_box" style="margin-top: 10px;">
        <div class="container">
            <div class="title_box" style="border-radius: 5px 5px 0px 0px;">
                <h2><a href="/bai-viet/tin-tuc.html" class="link">Tin tức mới nhất</a></h2>
                <a href="/bai-viet/tin-tuc.html" class="more_right">Xem tất cả <i class="fa fa-chevron-right"></i></a>
            </div>
            <div class="tab_box">
                <div class="tab" style="padding-bottom: 0px; display: flex;">
                    <div class="box_news_left">
                        {tintuc_big}
                    </div>
                    <div class="box_news_right">
                        <div class="list_news scroll">
                            {tintuc_small}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    {footer}
    {script_footer}
    <script>
        var slide_recent = new Swiper('.slide_category', {
            direction: 'horizontal',
            slidesPerView: 5,
            loop: true,
            observer: true,
            observeParents: true,
            pagination: { el: '.swiper-pagination', clickable: true },
            autoplay: { delay: 3000 },
            navigation: {
                nextEl: '.slide_category .next',
                prevEl: '.slide_category .prev',
                disabledClass: 'hide_button',
                hiddenClass: 'hide_button'
            }
        });

        if ($(window).width() < 480) {
            var sl = 2;
        } else {
            var sl = 3;
        }

        var slide_product = new Swiper('.slide_product', {
            direction: 'horizontal',
            slidesPerView: sl,
            loop: true,
            pagination: { el: '.swiper-pagination', clickable: true },
            navigation: {
                nextEl: '.slide_product .next',
                prevEl: '.slide_product .prev',
                disabledClass: 'hide_button',
                hiddenClass: 'hide_button'
            }
        });

        var slide_banner = new Swiper('.slide_top', {
            direction: 'horizontal',
            slidesPerView: 1,
            loop: true,
            observer: true,
            observeParents: true,
            autoplay: { delay: 3000 },
            pagination: { el: '.swiper-pagination', clickable: true },
            navigation: {
                nextEl: '.box_slide .next',
                prevEl: '.box_slide .prev'
            }
        });

        var slide_brand_top_doitac_hai = new Swiper('.slide_brand_top_doitac_hai', {
            direction: 'horizontal',
            slidesPerView: 2,
            spaceBetween: 10,
            loop: true,
            observer: true,
            observeParents: true,
            autoplay: { delay: 5000 },
            navigation: {
                nextEl: '.home_brand_doitac_hai .next',
                prevEl: '.home_brand_doitac_hai .prev'
            },
            breakpoints: {
                320: { slidesPerView: 1 },
                768: { slidesPerView: 2 },
                1024: { slidesPerView: 2 }
            }
        });
    </script>
<link rel="stylesheet" href="/skin/css/cart-animation.css?v=<?php echo time(); ?>">

<!-- Cart Animation JS -->
<script src="/js/cart-animation.js?v=<?php echo time(); ?>"></script>
</body>

</html>