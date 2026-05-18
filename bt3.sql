USE RikkeiClinicDB;

-- Xóa thủ tục cũ nếu đã tồn tại
DROP PROCEDURE IF EXISTS DispenseMedicine;

DELIMITER //

CREATE PROCEDURE DispenseMedicine(
    IN p_patient_id INT,
    IN p_medicine_id INT,
    IN p_quantity INT,
    OUT p_status_message VARCHAR(255)
)
BEGIN
    -- Khai báo các biến cục bộ để chứa dữ liệu tạm thời
    DECLARE v_current_stock INT;
    DECLARE v_medicine_price DECIMAL(18,2);

    -- Bộ xử lý an toàn: Nếu hệ thống lỗi bất ngờ, tự động hủy bỏ giao dịch
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status_message = 'Lỗi: Hệ thống gặp sự cố không mong muốn!';
    END;

    -- BƯỚC 1: Bắt đầu giao dịch
    START TRANSACTION;

    -- BƯỚC 2: Lấy số lượng tồn kho và giá tiền của thuốc hiện tại
    SELECT stock, price INTO v_current_stock, v_medicine_price 
    FROM Medicines 
    WHERE medicine_id = p_medicine_id;

    -- BƯỚC 3: Kiểm tra điều kiện kho hàng
    IF v_current_stock IS NULL THEN
        SET p_status_message = 'Lỗi: Không tìm thấy mã thuốc này trong hệ thống!';
        ROLLBACK;
        
    ELIF v_current_stock < p_quantity THEN
        -- Nếu kho không đủ, hoàn tác (Rollback) ngay lập tức
        SET p_status_message = 'Lỗi: Số lượng tồn kho không đủ';
        ROLLBACK;
        
    ELSE
        -- Nếu đủ điều kiện, tiến hành xử lý đồng bộ
        
        -- Thao tác 'Kho': Trừ đi số lượng trong bảng thuốc
        UPDATE Medicines 
        SET stock = stock - p_quantity 
        WHERE medicine_id = p_medicine_id;

        -- Thao tác 'Công nợ': Cộng dồn tiền (Số lượng * Đơn giá) cho bệnh nhân
        UPDATE Patient_Invoices 
        SET total_due = total_due + (p_quantity * v_medicine_price) 
        WHERE patient_id = p_patient_id;

        -- Xác nhận thành công, lưu vĩnh viễn dữ liệu
        COMMIT;
        SET p_status_message = 'Đã cấp phát thành công';
    END IF;

END //

DELIMITER ;