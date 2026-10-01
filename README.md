# Báo Cáo Chẩn Đoán CSDL & Tối Ưu Hệ Thống HealthSync

## 1. Gap Analysis (Báo cáo chẩn đoán lỗ hổng CSDL cũ)
So với UML Activity Diagram của quy trình "Đặt lịch và Khám bệnh", cơ sở dữ liệu legacy có các lỗ hổng nghiêm trọng sau:
1. **Trạng thái đa cấp bị đơn giản hóa:** Việc dùng `is_active BOOLEAN` chỉ biểu diễn được 2 trạng thái (Đúng/Sai), hoàn toàn không đáp ứng được quy trình vòng đời 5 trạng thái (`PENDING`, `CONFIRMED`, `CHECKED_IN`, `COMPLETED`, `CANCELLED`).
2. **Thiếu quản lý tài chính:** Thiếu các cột `deposit_amount` (tiền cọc) và `penalty_fee` (phí phạt), khiến hệ thống không thể xử lý phạt tiền cọc khi hủy lịch.
3. **Thiếu ghi nhận lý do hủy:** Không có cột `cancel_reason` để đối soát và chăm sóc khách hàng.
4. **Vắng mặt thực thể Đơn thuốc:** Thiếu hoàn toàn bảng `Prescriptions`, làm bác sĩ không thể lưu đơn thuốc khi hoàn thành ca khám.

---

## 2. Biện luận Thiết kế & Bảo vệ CSDL

### Q1: Ngăn chặn chèn Đơn thuốc khi lịch hẹn đang ở trạng thái PENDING?
- **Giải pháp ở tầng Database:** Sử dụng **Database Trigger** `BEFORE INSERT` trên bảng `Prescriptions`.
- **Cơ chế:** Trigger sẽ kiểm tra xem `status` trong bảng `Appointments` của `appointment_id` tương ứng có phải là `COMPLETED` hay không. Nếu không phải, trigger sẽ dùng câu lệnh `SIGNAL SQLSTATE` để quăng lỗi và hủy giao dịch.

### Q2: Tầm quan trọng của cột `penalty_fee` với kế toán & kiểm toán?
- Cột `penalty_fee` giúp minh bạch hóa dòng tiền giữa tiền cọc nhận vào (`deposit_amount`), phí phạt giữ lại (`penalty_fee`) và số tiền hoàn lại cho bệnh nhân.
- Nếu không có cột này, bộ phận kế toán không thể đối soát được doanh thu bất thường từ tiền phạt, dẫn đến lệch sổ sách kế toán cuối tháng.

### Q3: Sự nhất quán giữa UML Activity Diagram và ERD có vai trò gì trong bàn giao (Dev & BA)?
- Đảm bảo **Single Source of Truth** (Nguồn sự thật duy nhất): Giúp bộ phận Lập trình (Dev) xây dựng đúng logic backend mà bộ phận Phân tích (BA) đã thống nhất với khách hàng.
- Tránh tình trạng vỡ luồng nghiệp vụ trên production (như lỗi không lưu được tiền phạt hay không có chỗ kê đơn thuốc).

### Q4: Vì sao chọn `DECIMAL` thay vì `FLOAT/DOUBLE` cho dữ liệu tài chính?
- `FLOAT` và `DOUBLE` sử dụng biểu diễn số thực dấu phẩy động (IEEE 754) gây ra **lỗi sai số làm tròn (float precision error)**.
- `DECIMAL` lưu trữ chính xác từng chữ số thập phân, bảo đảm độ chính xác tuyệt đối trong tính toán tài chính.
