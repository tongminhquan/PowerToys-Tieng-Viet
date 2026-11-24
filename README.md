# Gói Việt hóa cho Microsoft PowerToys

Bản dịch tiếng Việt **không chính thức** cho giao diện [Microsoft PowerToys](https://github.com/microsoft/PowerToys), kèm script cài đặt và gỡ bỏ tự động.

Kho này **chỉ chứa bản dịch và script**, không chứa tệp nào của PowerToys. Script sẽ vá trực tiếp vào bản PowerToys đã cài trên máy bạn.

> Microsoft hiện chưa hỗ trợ tiếng Việt cho PowerToys (xem [microsoft/PowerToys#24101](https://github.com/microsoft/PowerToys/issues/24101)). Gói này giúp dùng tạm trong lúc chờ bản chính thức.

## Phạm vi dịch

- Khoảng **2.500 chuỗi** giao diện, áp dụng cho **27 tệp tài nguyên `.pri`** của các ứng dụng WinUI 3.
- Gồm: Cài đặt PowerToys, Truy cập nhanh, Bộ chọn màu, Đổi cỡ ảnh, Đổi tên hàng loạt, Xem nhanh tệp, Điều chỉnh màn hình, Hướng dẫn phím tắt, Thước đo màn hình, Kiểm tra khóa tệp, Dán nâng cao, Sửa tệp Hosts, Biến môi trường, Xem trước Registry, Quản lý bàn phím, Trích xuất văn bản, Gõ ký tự có dấu, Nhảy nhanh con trỏ…
- Tên các tiện ích cũng được dịch, ví dụ: *Always On Top* → **Luôn ở trên cùng**, *FancyZones* → **Chia vùng cửa sổ**, *ZoomIt* → **Phóng to & Ghi chú**.

Đã thử nghiệm trên PowerToys **v0.103.3151**. Bản dịch được ghép theo nội dung chuỗi tiếng Anh, nên vẫn dùng được với các phiên bản khác; chuỗi mới chưa có trong từ điển sẽ giữ nguyên tiếng Anh.

## Cài đặt

1. Tải kho này về (nút **Code → Download ZIP**, hoặc mục **Releases**) rồi giải nén.
2. Mở PowerShell trong thư mục vừa giải nén và chạy:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\install_vi.ps1
   ```

3. Mở lại PowerToys từ Start Menu.

Script sẽ:
- Tự tìm thư mục cài PowerToys (`%LOCALAPPDATA%\PowerToys` hoặc `C:\Program Files\PowerToys`).
- Sao lưu các tệp `.pri` gốc vào thư mục `backup\` (chỉ lần đầu).
- Vá bản dịch và kiểm tra từng tệp bằng `MRM.dll` của Microsoft trước khi ghi đè.
- Không sửa tệp `.exe` hay `.dll` nào, nên chữ ký số của Microsoft vẫn giữ nguyên.

Nếu bạn cài PowerToys cho toàn máy (trong `C:\Program Files`), hãy mở PowerShell bằng **Run as administrator**.

Chỉ muốn tạo và kiểm tra tệp mà chưa ghi đè vào PowerToys:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install_vi.ps1 -StageOnly
```

## Gỡ Việt hóa (quay về tiếng Anh)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\restore_en.ps1
```

Lệnh này chép lại các tệp gốc từ thư mục `backup\`.

## Sau khi PowerToys cập nhật

Bản cập nhật sẽ ghi đè lại tệp tiếng Anh. Khi đó:
1. Xóa thư mục `backup\` cũ (vì nó thuộc phiên bản trước).
2. Chạy lại `install_vi.ps1`.

## Sửa hoặc bổ sung bản dịch

Mọi bản dịch nằm trong `translations.json`, dạng `"chuỗi tiếng Anh": "chuỗi tiếng Việt"`. Sửa xong thì chạy lại `install_vi.ps1`.

Lưu ý giữ nguyên các ký hiệu giữ chỗ như `{0}`, `{1:N0}`, `%1!s!`, `\n` và các đường dẫn, tên phím.

Muốn tìm các chuỗi mới sau khi PowerToys cập nhật, chạy `extract_strings.ps1`. Kết quả nằm trong thư mục `extracted\`: `pri_to_translate.tsv` là các chuỗi chưa có bản dịch chính thức của Microsoft.

## Hạn chế

Một số thành phần không dùng tệp `.pri` nên vẫn hiển thị tiếng Anh:
- Các cửa sổ WPF cũ: FancyZones Editor, Workspaces Editor, menu khay của Awake, PowerToys Run.
- Menu chuột phải trên biểu tượng PowerToys ở khay hệ thống.

## Miễn trừ

Đây là dự án cộng đồng, không liên quan và không được Microsoft hỗ trợ. PowerToys là sản phẩm của Microsoft, phát hành theo giấy phép MIT.
