# PowerToys Tiếng Việt — Gói Việt Hóa Giao Diện Microsoft PowerToys

**PowerToys Tiếng Việt** là bộ gói ngôn ngữ và công cụ **Việt hóa giao diện Microsoft PowerToys** đầy đủ dành cho **Windows 10** và **Windows 11**. Giải pháp giúp chuyển toàn bộ menu cài đặt, thanh điều hướng, cửa sổ truy cập nhanh và các tiện ích trong bộ **Microsoft PowerToys** sang **tiếng Việt** rõ ràng, tự nhiên chỉ với một lệnh duy nhất.

- **Tải nhanh bản đóng gói (.zip):** [Tải về PowerToys-Tieng-Viet-v1.0.0.zip](https://github.com/tongminhquan/PowerToys-Tieng-Viet/releases/download/v1.0.0/PowerToys-Tieng-Viet-v1.0.0.zip)
- **Trang phát hành (Releases):** [github.com/tongminhquan/PowerToys-Tieng-Viet/releases](https://github.com/tongminhquan/PowerToys-Tieng-Viet/releases)

---

## Tính năng nổi bật của gói Việt hóa PowerToys

- **Việt hóa toàn diện:** Bao phủ hơn **2.535 mục từ điển** tương ứng hơn **11.250 chuỗi hiển thị** trên toàn bộ **27 tệp tài nguyên `.pri`** của các ứng dụng WinUI 3 trong PowerToys.
- **Việt hóa đầy đủ cả tên tiện ích & mô tả chi tiết:** Dịch đồng bộ thanh điều hướng bên trái, trang chủ Bảng điều khiển, cửa sổ Truy cập nhanh (Quick Access) và toàn bộ tùy chọn cấu hình bên trong.
- **An toàn tuyệt đối, giữ nguyên chữ ký số:** Chỉ cập nhật tệp tài nguyên chuỗi `.pri` và kiểm tra tính toàn vẹn trực tiếp bằng thư viện `MRM.dll` của Microsoft trước khi áp dụng — **không can thiệp vào bất kỳ tệp `.exe` hay `.dll` nào**.
- **Chỉ chứa bản dịch gọn nhẹ (~85 KB):** Kho lưu trữ chỉ chứa từ điển dịch `translations.json` và kịch bản cài/gỡ bằng mã nguồn mở PowerShell minh bạch.
- **Sao lưu & khôi phục 1 chạm:** Tự động sao lưu nguyên trạng tệp gốc vào thư mục `backup\` để có thể quay lại giao diện tiếng Anh bất cứ lúc nào.

---

## Hướng dẫn cài đặt tiếng Việt cho PowerToys

### Cách 1: Tải gói ZIP và chạy kịch bản cài đặt (Khuyên dùng)

1. Tải tệp **[PowerToys-Tieng-Viet-v1.0.0.zip](https://github.com/tongminhquan/PowerToys-Tieng-Viet/releases/download/v1.0.0/PowerToys-Tieng-Viet-v1.0.0.zip)** (hoặc chọn **Code → Download ZIP**) và giải nén ra một thư mục bất kỳ.
2. Mở **PowerShell** tại thư mục vừa giải nén và chạy lệnh:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\install_vi.ps1
   ```

3. Mở lại **PowerToys** từ **Start Menu** để sử dụng giao diện **Cài đặt PowerToys** bằng tiếng Việt.

> **Lưu ý:** Kịch bản tự động nhận diện cả bản cài theo người dùng (`%LOCALAPPDATA%\PowerToys`) lẫn bản cài toàn máy (`C:\Program Files\PowerToys`). Nếu bạn cài PowerToys trong `C:\Program Files`, hãy mở PowerShell với quyền **Run as administrator**.

### Cách 2: Clone trực tiếp bằng Git

```powershell
git clone https://github.com/tongminhquan/PowerToys-Tieng-Viet.git
cd PowerToys-Tieng-Viet
powershell -NoProfile -ExecutionPolicy Bypass -File .\install_vi.ps1
```

### Kiểm thử trước không ghi đè (Tùy chọn)

Nếu chỉ muốn tạo thử và xác minh tệp `.pri` bằng `MRM.dll` mà chưa áp dụng vào PowerToys:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install_vi.ps1 -StageOnly
```

---

## Danh sách các công cụ PowerToys được Việt hóa

| Tên gốc trong PowerToys | Tên hiển thị Tiếng Việt | Chức năng chính trên Windows |
| :--- | :--- | :--- |
| **Dashboard / General** | **Trang chủ / Cài đặt chung** | Tổng quan tiện ích, khởi động cùng Windows, giao diện Sáng/Tối, sao lưu & cập nhật |
| **Quick Access** | **Truy cập nhanh** | Cửa sổ bật nhanh các công cụ PowerToys từ khay hệ thống |
| **Always On Top** | **Luôn ở trên cùng** | Ghim cửa sổ ứng dụng bất kỳ luôn nổi lên trên các cửa sổ khác |
| **Awake** | **Giữ máy luôn bật** | Ngăn máy tính tự tắt màn hình hoặc chuyển sang chế độ ngủ khi đang làm việc |
| **Color Picker** | **Bộ chọn màu** | Lấy mã màu (`HEX`, `RGB`, `HSL`, `OKLCH`...) ở bất kỳ vị trí nào trên màn hình |
| **Command Palette** | **Bảng lệnh** | Trình khởi chạy ứng dụng, tìm kiếm tệp và thực thi lệnh nhanh thế hệ mới |
| **Command Not Found** | **Gợi ý lệnh thiếu** | Tự động gợi ý gói cài đặt `winget` khi nhập lệnh chưa có trong PowerShell |
| **Crop And Lock** | **Cắt & Khóa cửa sổ** | Cắt gọn một vùng cửa sổ ứng dụng thành cửa sổ thu nhỏ độc lập |
| **Environment Variables** | **Biến môi trường** | Quản lý, tạo hồ sơ và chỉnh sửa nhanh biến môi trường hệ thống & người dùng |
| **FancyZones** | **Chia vùng cửa sổ** | Chia bố cục màn hình thông minh để sắp xếp đa nhiệm nhiều cửa sổ |
| **File Locksmith** | **Kiểm tra khóa tệp** | Kiểm tra tiến trình nào đang giữ tệp/thư mục không xóa được và giải phóng nhanh |
| **Find My Mouse / Mouse Utilities** | **Tìm vị trí chuột / Đánh dấu nhấp chuột / Tâm ngắm con trỏ / Nhảy nhanh con trỏ** | Bộ công cụ hỗ trợ định vị con trỏ, thuyết trình và di chuyển chuột trên màn hình lớn |
| **Grab And Move** | **Nắm & Di chuyển** | Giữ phím bổ trợ và kéo ở bất kỳ đâu trong cửa sổ để di chuyển hoặc đổi kích thước |
| **Hosts File Editor** | **Sửa tệp Hosts** | Chỉnh sửa, bật/tắt nhanh từng dòng cấu hình tên miền trong tệp `hosts` |
| **Image Resizer** | **Đổi cỡ ảnh** | Thay đổi kích thước hàng loạt hình ảnh ngay trong menu chuột phải File Explorer |
| **Keyboard Manager** | **Quản lý bàn phím** | Đổi chức năng phím và gán lại tổ hợp phím tắt trên toàn hệ thống |
| **Light Switch** | **Đổi chế độ Sáng/Tối** | Tự động chuyển giao diện Sáng/Tối của Windows theo khung giờ hoặc bình minh/hoàng hôn |
| **Mouse Without Borders** | **Dùng chung chuột & phím** | Điều khiển nhiều máy tính Windows trong mạng nội bộ bằng một bộ chuột và bàn phím |
| **New+** | **Tạo nhanh từ mẫu** | Tạo tệp và thư mục mới từ bộ mẫu cá nhân hóa ngay trong menu chuột phải |
| **Peek** | **Xem nhanh tệp** | Nhấn phím tắt để xem trước nhanh ảnh, tài liệu, mã nguồn trong File Explorer |
| **PowerDisplay** | **Điều chỉnh màn hình** | Chỉnh độ sáng, độ tương phản, nhiệt độ màu cho nhiều màn hình rời qua `DDC/CI` |
| **PowerRename** | **Đổi tên hàng loạt** | Đổi tên hàng loạt tệp và thư mục hỗ trợ tìm/thay thế và biểu thức chính quy (`Regex`) |
| **PowerToys Run** | **Khởi chạy nhanh** | Thanh tìm kiếm và mở nhanh ứng dụng, tệp, phép tính bằng phím tắt `Alt + Space` |
| **Quick Accent** | **Gõ ký tự có dấu** | Nhập nhanh các chữ cái có dấu và ký hiệu đặc biệt |
| **Registry Preview** | **Xem trước Registry** | Xem cấu trúc cây trực quan và chỉnh sửa tệp `.reg` trước khi ghi vào Registry |
| **Screen Ruler** | **Thước đo màn hình** | Đo khoảng cách pixel và căn lề giao diện trực tiếp trên màn hình |
| **Shortcut Guide** | **Hướng dẫn phím tắt** | Hiển thị bảng tra cứu nhanh các phím tắt Windows thông dụng |
| **Text Extractor** | **Trích xuất văn bản** | Quét và sao chép chữ từ hình ảnh hoặc bất kỳ vùng nào trên màn hình (`OCR`) |
| **Window Hopper** | **Chuyển nhanh cửa sổ** | Chuyển đổi nhanh giữa các cửa sổ thuộc cùng một ứng dụng đang mở |
| **Workspaces** | **Không gian làm việc** | Mở đồng loạt bộ ứng dụng làm việc vào đúng vị trí bố cục chỉ với một cú nhấp |
| **ZoomIt** | **Phóng to & Ghi chú** | Phóng to màn hình, vẽ ghi chú trực tiếp, đếm ngược và quay màn hình khi thuyết trình |

---

## Cách gỡ Việt hóa (Khôi phục tiếng Anh gốc)

Khi muốn quay về giao diện tiếng Anh mặc định ban đầu, mở PowerShell trong thư mục công cụ và chạy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\restore_en.ps1
```

Kịch bản sẽ tự động khôi phục toàn bộ tệp `.pri` gốc từ thư mục `backup\`.

---

## Cập nhật hoặc tùy chỉnh từ điển dịch

- **Sau khi PowerToys cập nhật phiên bản mới:** Bản cập nhật sẽ ghi đè lại tệp `.pri` tiếng Anh mới. Bạn chỉ cần xóa thư mục `backup\` cũ rồi chạy lại `.\install_vi.ps1`. Bản dịch đối sánh theo nội dung chuỗi tiếng Anh nên tương thích xuyên suốt nhiều phiên bản PowerToys (đã kiểm thử đầy đủ trên `v0.103.x`).
- **Tự chỉnh sửa câu chữ tiếng Việt:** Mở tệp `translations.json` bằng trình soạn thảo văn bản UTF-8, sửa nội dung tiếng Việt theo ý muốn (giữ nguyên các ký hiệu định dạng như `{0}`, `{1:N0}`, `%1!s!`, `\n`), sau đó chạy lại `.\install_vi.ps1`.
- **Trích xuất chuỗi mới:** Chạy `.\extract_strings.ps1` để quét và xuất danh sách chuỗi mới trong thư mục `extracted\` khi PowerToys bổ sung tính năng mới.

---

## Câu hỏi thường gặp (FAQ)

### 1. Làm sao để thiết lập giao diện tiếng Việt cho PowerToys trên Windows 10 và Windows 11?
Bạn chỉ cần tải bộ **PowerToys Tiếng Việt** tại kho lưu trữ này, giải nén và chạy lệnh `powershell -NoProfile -ExecutionPolicy Bypass -File .\install_vi.ps1`, sau đó mở lại PowerToys để hiển thị giao diện tiếng Việt đầy đủ.

### 2. Gói Việt hóa PowerToys có an toàn không?
Hoàn toàn an toàn. Bộ công cụ chỉ chứa từ điển văn bản JSON và mã nguồn mở PowerShell, không chứa tệp thực thi đóng gói sẵn và không sửa đổi bất kỳ tệp `.exe` hay `.dll` nào của PowerToys. Mọi tệp tài nguyên `.pri` đều được kiểm tra hợp lệ bằng `MRM.dll` trước khi chép vào ứng dụng.

### 3. Có còn phần nào hiển thị tiếng Anh không?
Toàn bộ giao diện cài đặt chính và 27 ứng dụng WinUI 3 đều được Việt hóa. Một vài hộp thoại phụ sử dụng kiến trúc WPF/Win32 cũ không dùng tệp `.pri` (như trình chỉnh sửa bố cục *FancyZones Editor*, *Workspaces Editor* hoặc menu chuột phải cấp thấp ở khay hệ thống) sẽ vẫn giữ tiếng Anh.

---

## Giấy phép & Ghi nhận

Dự án bản địa hóa cộng đồng mã nguồn mở dành cho người dùng Việt Nam, độc lập và không trực thuộc Microsoft. [Microsoft PowerToys](https://github.com/microsoft/PowerToys) là sản phẩm mã nguồn mở của Microsoft theo giấy phép MIT.
