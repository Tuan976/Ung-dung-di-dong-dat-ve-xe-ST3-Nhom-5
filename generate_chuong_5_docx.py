import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

def set_cell_borders(cell, top=None, bottom=None, left=None, right=None):
    """Set cell borders with specific xml attributes"""
    tcPr = cell._tc.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    
    borders = {'top': top, 'bottom': bottom, 'left': left, 'right': right}
    for border_name, border_style in borders.items():
        if border_style is not None:
            el = OxmlElement(f'w:{border_name}')
            for key, val in border_style.items():
                el.set(qn(f'w:{key}'), str(val))
            tcBorders.append(el)
    tcPr.append(tcBorders)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    """Set inner padding for table cells"""
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('top', top), ('bottom', bottom), ('left', left), ('right', right)]:
        node = OxmlElement(f'w:{m}')
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

def create_document():
    doc = docx.Document()
    
    # Page setup (A4, Left 3cm, Right 2cm, Top 2cm, Bottom 2cm)
    for section in doc.sections:
        section.top_margin = Inches(0.79)     # 2 cm
        section.bottom_margin = Inches(0.79)  # 2 cm
        section.left_margin = Inches(1.18)    # 3 cm
        section.right_margin = Inches(0.79)   # 2 cm
        section.page_width = Inches(8.27)     # A4
        section.page_height = Inches(11.69)
        
    # Set default style to Times New Roman
    style = doc.styles['Normal']
    font = style.font
    font.name = 'Times New Roman'
    font.size = Pt(13)
    font.color.rgb = RGBColor(0, 0, 0)
    
    # Title: CHƯƠNG 5. KIỂM THỬ VÀ ĐÁNH GIÁ
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(0)
    title_p.paragraph_format.space_after = Pt(12)
    title_p.paragraph_format.line_spacing = 1.3
    title_run = title_p.add_run("CHƯƠNG 5. KIỂM THỬ VÀ ĐÁNH GIÁ")
    title_run.font.name = 'Times New Roman'
    title_run.font.size = Pt(16)
    title_run.font.bold = True
    
    # 5.1. Môi trường và phương pháp kiểm thử
    h1 = doc.add_paragraph()
    h1.paragraph_format.space_before = Pt(8)
    h1.paragraph_format.space_after = Pt(4)
    h1.paragraph_format.line_spacing = 1.3
    r_h1 = h1.add_run("5.1. Môi trường và phương pháp kiểm thử")
    r_h1.font.name = 'Times New Roman'
    r_h1.font.size = Pt(13)
    r_h1.font.bold = True
    
    p1 = doc.add_paragraph()
    p1.paragraph_format.space_after = Pt(6)
    p1.paragraph_format.line_spacing = 1.3
    p1.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    r_p1 = p1.add_run("Nhóm tiến hành kiểm thử ứng dụng HUTECH BUS trên thiết bị hoặc trình giả lập, nhằm đánh giá giao diện, khả năng điều hướng và hoạt động của các chức năng chính. Phương pháp kiểm thử chủ yếu là thực hiện thao tác trực tiếp và kiểm tra kết quả hiển thị.")
    r_p1.font.name = 'Times New Roman'
    r_p1.font.size = Pt(13)
    
    # 5.2. Kiểm thử các chức năng chính
    h2 = doc.add_paragraph()
    h2.paragraph_format.space_before = Pt(8)
    h2.paragraph_format.space_after = Pt(4)
    h2.paragraph_format.line_spacing = 1.3
    r_h2 = h2.add_run("5.2. Kiểm thử các chức năng chính")
    r_h2.font.name = 'Times New Roman'
    r_h2.font.size = Pt(13)
    r_h2.font.bold = True
    
    p2 = doc.add_paragraph()
    p2.paragraph_format.space_after = Pt(6)
    p2.paragraph_format.line_spacing = 1.3
    p2.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    r_p2 = p2.add_run("Các chức năng được kiểm thử gồm đăng nhập, trang chủ, tìm kiếm chuyến xe, xem chi tiết chuyến xe, chọn ghế, xem vé và quản lý hồ sơ cá nhân. Quá trình kiểm thử tập trung vào tính chính xác của dữ liệu và khả năng xử lý lỗi.")
    r_p2.font.name = 'Times New Roman'
    r_p2.font.size = Pt(13)
    
    # 5.3. Kết quả kiểm thử
    h3 = doc.add_paragraph()
    h3.paragraph_format.space_before = Pt(8)
    h3.paragraph_format.space_after = Pt(4)
    h3.paragraph_format.line_spacing = 1.3
    r_h3 = h3.add_run("5.3. Kết quả kiểm thử")
    r_h3.font.name = 'Times New Roman'
    r_h3.font.size = Pt(13)
    r_h3.font.bold = True
    
    p3 = doc.add_paragraph()
    p3.paragraph_format.space_after = Pt(6)
    p3.paragraph_format.line_spacing = 1.3
    p3.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    r_p3 = p3.add_run("Kết quả kiểm thử được tổng hợp theo từng chức năng như sau:")
    r_p3.font.name = 'Times New Roman'
    r_p3.font.size = Pt(13)
    
    # Table exactly matching screenshot style
    table_data = [
        ("Chức năng", "Kết quả"),
        ("Đăng nhập", "Đăng nhập thành công với tài khoản hợp lệ, chuyển hướng đúng vào màn hình chính. Khi nhập sai tài khoản hoặc mật khẩu, hệ thống hiển thị thông báo lỗi rõ ràng. Đánh giá: Đạt."),
        ("Tìm kiếm chuyến xe", "Lọc và hiển thị chính xác danh sách các chuyến xe theo điểm đi, điểm đến và ngày khởi hành; hiển thị đầy đủ thông tin thời gian xuất bến, giá vé và số ghế còn trống. Đánh giá: Đạt."),
        ("Xem chi tiết chuyến xe", "Hiển thị đầy đủ thông tin chi tiết về hành trình, sơ đồ ghế 2 tầng trực quan; chọn ghế và cập nhật trạng thái theo thời gian thực, tự động tính tổng tiền chính xác. Đánh giá: Đạt."),
        ("Hồ sơ cá nhân", "Hiển thị đúng thông tin người dùng; cập nhật họ tên, số điện thoại và đổi mật khẩu thành công; chức năng đăng xuất hoạt động an toàn và xóa phiên đăng nhập. Đánh giá: Đạt.")
    ]
    
    table = doc.add_table(rows=len(table_data), cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    
    col_widths = [Inches(2.2), Inches(4.3)]
    
    border_style = {'val': 'single', 'sz': 6, 'space': 0, 'color': '000000'}
    
    for row_idx, row in enumerate(table.rows):
        # Allow row to cantSplit
        trPr = row._tr.get_or_add_trPr()
        trPr.append(OxmlElement('w:cantSplit'))
        
        for col_idx, cell in enumerate(row.cells):
            cell.width = col_widths[col_idx]
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            set_cell_borders(cell, border_style, border_style, border_style, border_style)
            set_cell_margins(cell, top=120, bottom=120, left=150, right=150)
            
            p = cell.paragraphs[0]
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.2
            
            text = table_data[row_idx][col_idx]
            run = p.add_run(text)
            run.font.name = 'Times New Roman'
            run.font.size = Pt(12)
            
            if row_idx == 0:
                run.font.bold = True
                p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
            else:
                if col_idx == 0:
                    run.font.bold = True
                    p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT
                else:
                    p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
                    
    # Note under table matching image
    note_p = doc.add_paragraph()
    note_p.paragraph_format.space_before = Pt(6)
    note_p.paragraph_format.space_after = Pt(12)
    note_p.paragraph_format.line_spacing = 1.3
    note_p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    r_note = note_p.add_run("Kết quả kiểm thử cho thấy toàn bộ các chức năng cốt lõi của ứng dụng HUTECH BUS đều hoạt động ổn định, chính xác theo thiết kế và đạt yêu cầu đặt ra.")
    r_note.font.name = 'Times New Roman'
    r_note.font.size = Pt(13)
    r_note.font.italic = True
    
    # 5.3.2 Detailed Test Cases (Ca kiểm thử chi tiết)
    tc_h = doc.add_paragraph()
    tc_h.paragraph_format.space_before = Pt(8)
    tc_h.paragraph_format.space_after = Pt(4)
    tc_h.paragraph_format.line_spacing = 1.3
    r_tch = tc_h.add_run("Bảng chi tiết các ca kiểm thử (Test Cases):")
    r_tch.font.name = 'Times New Roman'
    r_tch.font.size = Pt(13)
    r_tch.font.bold = True
    
    tc_data = [
        ("Mã TC", "Tên ca kiểm thử", "Dữ liệu đầu vào", "Kết quả mong muốn", "Kết quả thực tế", "Đánh giá"),
        ("TC01", "Đăng nhập hợp lệ", "SĐT: 0901234567\nMật khẩu: 123456", "Đăng nhập thành công, chuyển vào Trang chủ", "Đăng nhập thành công, lưu phiên làm việc", "Đạt"),
        ("TC02", "Đăng nhập sai mật khẩu", "SĐT: 0901234567\nMật khẩu: sai_pass", "Thông báo: 'Mật khẩu không chính xác'", "Hiển thị đúng thông báo lỗi", "Đạt"),
        ("TC03", "Tìm kiếm chuyến xe", "Đi: TP.HCM\nĐến: Đà Lạt", "Hiển thị danh sách chuyến xe phù hợp", "Hiển thị đúng danh sách chuyến xe và giá vé", "Đạt"),
        ("TC04", "Chọn ghế trên sơ đồ xe", "Chọn ghế A01, A02", "Ghế đổi màu chọn, cập nhật tổng tiền", "Đổi màu ghế, hiển thị đúng tổng giá vé", "Đạt"),
        ("TC05", "Chọn ghế đã bán", "Nhấp vào ghế B03 (đã bán)", "Không cho chọn, giữ nguyên trạng thái", "Không chọn được ghế đã bán", "Đạt"),
        ("TC06", "Xác nhận đặt vé", "Tên: Nguyễn Văn A\nSĐT: 0901234567", "Tạo mã vé, hiển thị thông tin vé", "Tạo vé thành công, lưu vào lịch sử", "Đạt"),
        ("TC07", "Cập nhật hồ sơ cá nhân", "Họ tên mới: Nguyễn Văn B", "Cập nhật dữ liệu thành công", "Họ tên mới hiển thị ngay lập tức", "Đạt"),
    ]
    
    table_tc = doc.add_table(rows=len(tc_data), cols=6)
    table_tc.alignment = WD_TABLE_ALIGNMENT.CENTER
    table_tc.autofit = False
    
    tc_col_widths = [Inches(0.8), Inches(1.3), Inches(1.3), Inches(1.3), Inches(1.3), Inches(0.5)]
    
    for row_idx, row in enumerate(table_tc.rows):
        trPr = row._tr.get_or_add_trPr()
        trPr.append(OxmlElement('w:cantSplit'))
        
        for col_idx, cell in enumerate(row.cells):
            cell.width = tc_col_widths[col_idx]
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            set_cell_borders(cell, border_style, border_style, border_style, border_style)
            set_cell_margins(cell, top=80, bottom=80, left=100, right=100)
            
            p = cell.paragraphs[0]
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.15
            
            text = tc_data[row_idx][col_idx]
            run = p.add_run(text)
            run.font.name = 'Times New Roman'
            run.font.size = Pt(11)
            
            if row_idx == 0:
                run.font.bold = True
                p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
            else:
                if col_idx in (0, 5):
                    if col_idx == 5:
                        run.font.bold = True
                    p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
                else:
                    p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT
                    
    # 5.4. Đánh giá và nhận xét chung
    h4 = doc.add_paragraph()
    h4.paragraph_format.space_before = Pt(12)
    h4.paragraph_format.space_after = Pt(4)
    h4.paragraph_format.line_spacing = 1.3
    r_h4 = h4.add_run("5.4. Đánh giá và nhận xét chung")
    r_h4.font.name = 'Times New Roman'
    r_h4.font.size = Pt(13)
    r_h4.font.bold = True
    
    # 5.4.1. Ưu điểm
    h41 = doc.add_paragraph()
    h41.paragraph_format.space_before = Pt(4)
    h41.paragraph_format.space_after = Pt(2)
    h41.paragraph_format.line_spacing = 1.3
    r_h41 = h41.add_run("5.4.1. Ưu điểm đạt được")
    r_h41.font.name = 'Times New Roman'
    r_h41.font.size = Pt(13)
    r_h41.font.bold = True
    
    p_uudiem = doc.add_paragraph()
    p_uudiem.paragraph_format.space_after = Pt(6)
    p_uudiem.paragraph_format.line_spacing = 1.3
    p_uudiem.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    r_uudiem = p_uudiem.add_run(
        "• Giao diện hiện đại, trực quan: Bố cục màu sắc hài hòa, sơ đồ chọn ghế rõ ràng, thao tác đơn giản giúp người dùng nhanh chóng làm quen.\n"
        "• Độ chính xác dữ liệu cao: Dữ liệu chuyến đi, giá vé và trạng thái ghế trống được đồng bộ theo thời gian thực từ cơ sở dữ liệu.\n"
        "• Xử lý lỗi tốt: Kiểm soát dữ liệu nhập vào chặt chẽ, không xảy ra hiện tượng dừng ứng dụng đột ngột (crash)."
    )
    r_uudiem.font.name = 'Times New Roman'
    r_uudiem.font.size = Pt(13)
    
    # 5.4.2. Hạn chế và hướng phát triển
    h42 = doc.add_paragraph()
    h42.paragraph_format.space_before = Pt(4)
    h42.paragraph_format.space_after = Pt(2)
    h42.paragraph_format.line_spacing = 1.3
    r_h42 = h42.add_run("5.4.2. Hạn chế và hướng phát triển")
    r_h42.font.name = 'Times New Roman'
    r_h42.font.size = Pt(13)
    r_h42.font.bold = True
    
    p_hancie = doc.add_paragraph()
    p_hancie.paragraph_format.space_after = Pt(6)
    p_hancie.paragraph_format.line_spacing = 1.3
    p_hancie.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    r_hancie = p_hancie.add_run(
        "• Hạn chế: Cần kết nối Internet liên tục để tải dữ liệu; tính năng thanh toán trực tuyến qua cổng thứ ba (VNPay, MoMo) đang ở chế độ thử nghiệm (Sandbox).\n"
        "• Hướng phát triển: Tích hợp hệ thống thông báo đẩy (Push Notification) nhắc nhở lịch trình xe chạy và bản đồ định vị GPS theo dõi xe di chuyển thời gian thực."
    )
    r_hancie.font.name = 'Times New Roman'
    r_hancie.font.size = Pt(13)

    output_path = r"d:\WebDatVeXe\Chuong_5_Kiem_Thu_Va_Danh_Gia.docx"
    doc.save(output_path)
    print(f"File created successfully at: {output_path}")

if __name__ == "__main__":
    create_document()
