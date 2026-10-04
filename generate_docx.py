import docx
from docx.shared import Inches, Pt, RGBColor, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

doc = docx.Document()

# === PAGE SETTINGS ===
section = doc.sections[0]
section.page_width = Cm(29.7)
section.page_height = Cm(21.0)
section.left_margin = Cm(1.5)
section.right_margin = Cm(1.5)
section.top_margin = Cm(1.5)
section.bottom_margin = Cm(1.5)

# === DOCUMENT TITLE ===
title = doc.add_heading('PHAN TICH WIDGET VA UI - UNG DUNG DAT VE XE', 0)
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
doc.add_paragraph('')

def set_cell_background(cell, hex_color):
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:fill'), hex_color)
    shd.set(qn('w:val'), 'clear')
    tcPr.append(shd)

def add_section_title(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(12)
    run = p.add_run(f'== {text} ==')
    run.font.size = Pt(14)
    run.font.bold = True
    run.font.color.rgb = RGBColor(0, 70, 127)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    doc.add_paragraph('')

def add_widget_table(doc, screen_name, widgets):
    """
    widgets = list of dicts:
    {
      'name': str,
      'code': str,
      'function': str,
      'ui_note': str
    }
    """
    # Screen sub-heading
    p = doc.add_paragraph()
    run = p.add_run(screen_name)
    run.font.size = Pt(13)
    run.font.bold = True
    run.font.color.rgb = RGBColor(0, 70, 127)

    table = doc.add_table(rows=1, cols=2)
    table.style = 'Table Grid'
    table.alignment = WD_TABLE_ALIGNMENT.CENTER

    # Set column widths
    for row in table.rows:
        row.cells[0].width = Cm(13)
        row.cells[1].width = Cm(12)

    # Header row
    hdr = table.rows[0].cells
    set_cell_background(hdr[0], 'D9D9D9')
    set_cell_background(hdr[1], 'D9D9D9')

    for i, h in enumerate(['Widget', 'UI (Mo ta giao dien)']):
        p = hdr[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(h)
        r.font.bold = True
        r.font.size = Pt(12)

    for w in widgets:
        row = table.add_row()
        row.cells[0].width = Cm(13)
        row.cells[1].width = Cm(12)

        # === WIDGET COLUMN ===
        c0 = row.cells[0]

        # Widget name (red, bold)
        p_name = c0.paragraphs[0]
        p_name.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r_name = p_name.add_run(w['name'])
        r_name.font.bold = True
        r_name.font.size = Pt(11)
        r_name.font.color.rgb = RGBColor(192, 0, 0)

        # Code block (Consolas, dark background-like)
        p_code = c0.add_paragraph()
        r_code = p_code.add_run(w['code'])
        r_code.font.name = 'Consolas'
        r_code.font.size = Pt(8)
        r_code.font.color.rgb = RGBColor(30, 30, 30)
        set_cell_background(c0, 'F2F2F2')

        # Function description (yellow highlight style)
        p_func = c0.add_paragraph()
        p_func.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r_func = p_func.add_run(w['function'])
        r_func.font.bold = True
        r_func.font.size = Pt(9)
        r_func.font.color.rgb = RGBColor(0, 70, 127)

        # === UI COLUMN ===
        c1 = row.cells[1]
        p_ui = c1.paragraphs[0]
        p_ui.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r_placeholder = p_ui.add_run('[CHEN ANH SCREENSHOT]')
        r_placeholder.font.bold = True
        r_placeholder.font.size = Pt(9)
        r_placeholder.font.color.rgb = RGBColor(128, 128, 128)

        p_ui_note = c1.add_paragraph()
        p_ui_note.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r_ui_note = p_ui_note.add_run(w['ui_note'])
        r_ui_note.font.size = Pt(9)
        r_ui_note.font.color.rgb = RGBColor(80, 80, 80)

    doc.add_paragraph('')

# =============================================
# 1. MAN HINH SPLASH
# =============================================
add_section_title(doc, '1. MAN HINH SPLASH (Khoi dong)')

add_widget_table(doc, 'Class: SplashScreen | Route: /', [
    {
        'name': 'Scaffold + SafeArea',
        'code': 'Scaffold(\n  backgroundColor: Colors.white,\n  body: SafeArea(\n    child: Center(\n      child: Column(...)\n    )\n  )\n)',
        'function': 'Tao khung man hinh trang, SafeArea dam bao noi dung khong bi che boi thanh trang thai (status bar)',
        'ui_note': 'Man hinh trang hoan toan, noi dung can giua theo ca chieu doc lan ngang'
    },
    {
        'name': 'Image.asset + Text',
        'code': 'Image.asset("assets/logo.png",\n  width: 120, height: 120),\nSizedBox(height: 16),\nText("WebDatVeXe",\n  style: TextStyle(\n    fontSize: 28,\n    fontWeight: FontWeight.w800\n  )\n)',
        'function': 'Hien thi logo va ten ung dung o giua man hinh',
        'ui_note': 'Logo hieu xe o tren, chu ten app to dam phia duoi'
    },
    {
        'name': 'CircularProgressIndicator',
        'code': 'CircularProgressIndicator(\n  color: Color(0xFF00639B),\n  strokeWidth: 2,\n)',
        'function': 'Hien thi vong quay cho khi app dang kiem tra trang thai dang nhap tu backend',
        'ui_note': 'Vong tron xoay mau xanh nho o phia duoi logo'
    },
])

# =============================================
# 2. MAN HINH DANG NHAP
# =============================================
add_section_title(doc, '2. MAN HINH DANG NHAP (Login)')

add_widget_table(doc, 'Class: LoginScreen | Route: /login', [
    {
        'name': 'SingleChildScrollView + Column',
        'code': 'SingleChildScrollView(\n  padding: EdgeInsets.all(24),\n  child: Column(\n    crossAxisAlignment:\n      CrossAxisAlignment.start,\n    children: [...]\n  )\n)',
        'function': 'Cho phep cuon noi dung khi ban phim ao hien ra, Column sap xep cac truong nhap lieu theo hang doc',
        'ui_note': 'Trang dang nhap co the cuon doc khi ban phim mo, tranh bi an mat cac o nhap'
    },
    {
        'name': 'TextFormField (Email)',
        'code': 'TextFormField(\n  controller: _emailController,\n  keyboardType:\n    TextInputType.emailAddress,\n  decoration: InputDecoration(\n    labelText: "Email",\n    prefixIcon: Icon(Icons.email),\n    border: OutlineInputBorder()\n  )\n)',
        'function': 'O nhap email, tu dong hien ban phim email, co icon cai thu o ben trai',
        'ui_note': 'O nhap vien tron, co chu goi y "Email" va icon phong bi thu'
    },
    {
        'name': 'TextFormField (Password)',
        'code': 'TextFormField(\n  controller: _passwordController,\n  obscureText: _obscure,\n  decoration: InputDecoration(\n    labelText: "Mat khau",\n    suffixIcon: IconButton(\n      icon: Icon(_obscure\n        ? Icons.visibility_off\n        : Icons.visibility),\n      onPressed: () => setState(\n        () => _obscure = !_obscure)\n    )\n  )\n)',
        'function': 'O nhap mat khau, che ky tu, nut con mat o ben phai de an/hien mat khau',
        'ui_note': 'O nhap mat khau co dau cham giu bi mat, nut con mat de hien/an'
    },
    {
        'name': 'ElevatedButton (Dang nhap)',
        'code': 'ElevatedButton(\n  onPressed: _login,\n  style: ElevatedButton.styleFrom(\n    backgroundColor:\n      Color(0xFF0B192C),\n    minimumSize:\n      Size(double.infinity, 52),\n    shape: RoundedRectangleBorder(\n      borderRadius:\n        BorderRadius.circular(12))\n  ),\n  child: Text("Dang nhap")\n)',
        'function': 'Nut bam chinh de gui form dang nhap toi backend API /auth/login',
        'ui_note': 'Nut rong toan bo chieu ngang, mau xanh dam, chu trang, bo goc tron'
    },
])

# =============================================
# 3. MAN HINH TRANG CHU
# =============================================
add_section_title(doc, '3. MAN HINH TRANG CHU (Home)')

add_widget_table(doc, 'Class: HomeScreen | Route: /home', [
    {
        'name': 'Row (Header chao hoi)',
        'code': 'Row(\n  mainAxisAlignment:\n    MainAxisAlignment.spaceBetween,\n  children: [\n    Column(children: [\n      Text("Xin chao"),\n      Text("$greeting!") // Lay tu API\n    ]),\n    GestureDetector( // Nut avatar\n      onTap: () =>\n        context.push("/profile"),\n      child: Container(\n        child: Text(greeting[0])\n      )\n    )\n  ]\n)',
        'function': 'Thanh tieu de chao hoi nguoi dung theo ten that tu backend, avatar chu cai dieu huong sang trang tai khoan',
        'ui_note': 'Goc trai: chu "Xin chao" va ten nguoi dung. Goc phai: avatar tron chu cai'
    },
    {
        'name': 'Container (Search Card)',
        'code': 'Container(\n  decoration: BoxDecoration(\n    color: Colors.white,\n    borderRadius:\n      BorderRadius.circular(16),\n    boxShadow: [...]\n  ),\n  child: Column(children: [\n    // From field\n    // To field\n    // Swap button\n    // Date picker\n    // Search button\n  ])\n)',
        'function': 'The tim kiem chinh, chua toan bo form nhap diem di, diem den, ngay di. Co bong do noi bat tren nen',
        'ui_note': 'Khoi trang bo goc, co bong, chua cac o nhap lieu chon diem va ngay'
    },
    {
        'name': 'IconButton (Swap 2 dia diem)',
        'code': 'IconButton(\n  onPressed: _swapLocations,\n  icon: Icon(Icons.swap_vert,\n    color: Color(0xFF00639B)),\n)',
        'function': 'Nhan vao se doi cho Diem di va Diem den cho nhau bang ham setState',
        'ui_note': 'Nut mui ten 2 chieu len xuong nam giua 2 o diem di va diem den'
    },
    {
        'name': 'GestureDetector (City Picker)',
        'code': 'GestureDetector(\n  onTap: () async {\n    final result =\n      await _showCityPicker(\n        context, "Diem di", _from);\n    if (result != null)\n      setState(() => _from = result);\n  },\n  child: Container(...)\n)',
        'function': 'Nhan vao mo hop thoai chon thanh pho, goi API /locations de lay danh sach, tu dong dien vi tri hien tai qua GPS',
        'ui_note': 'O nhap gia truong dieu huong, mo Sheet chon thanh pho tu danh sach backend'
    },
    {
        'name': 'FloatingActionButton (SOS)',
        'code': 'FloatingActionButton(\n  onPressed: () =>\n    context.push("/sos"),\n  backgroundColor: Colors.red,\n  child: Icon(Icons.sos)\n)',
        'function': 'Nut khan cap no noi o goc phai duoi, bam vao mo man hinh SOS de lien lac khan cap',
        'ui_note': 'Nut tron do noi o goc phai duoi, chu SOS trang, lun o tren cung'
    },
    {
        'name': 'ListView.builder (Tuyen pho bien)',
        'code': 'SizedBox(\n  height: 180,\n  child: ListView.builder(\n    scrollDirection: Axis.horizontal,\n    itemCount: _popularRoutes.length,\n    itemBuilder: (context, index) {\n      return _buildRouteCard(\n        _popularRoutes[index]);\n    }\n  )\n)',
        'function': 'Danh sach cuon ngang hien thi cac tuyen xe pho bien, moi the la 1 tuyen kem gia tien',
        'ui_note': 'Cac the vuong nho xep hang ngang, vuot sang trai/phai de xem them tuyen'
    },
    {
        'name': 'BottomNavigationBar (4 tab)',
        'code': 'Row(children: [\n  _buildNavItem(0, Icons.home,\n    "Trang chu"),\n  _buildNavItem(1,\n    Icons.confirmation_number,\n    "Ve cua toi"),\n  _buildNavItem(2,\n    Icons.notifications,\n    "Thong bao"),\n  _buildNavItem(3,\n    Icons.person, "Tai khoan"),\n])',
        'function': 'Thanh dieu huong 4 tab duoi cung dung de chuyen giua cac man hinh chinh cua ung dung',
        'ui_note': 'Thanh trang phia duoi, tab dang chon co nen xanh nhat va chu dam'
    },
])

# =============================================
# 4. MAN HINH KET QUA TIM KIEM
# =============================================
add_section_title(doc, '4. MAN HINH KET QUA TIM KIEM (Search Results)')

add_widget_table(doc, 'Class: SearchResultsScreen | Route: /search_results', [
    {
        'name': 'FutureBuilder<List<Trip>>',
        'code': 'FutureBuilder<List<Trip>>(\n  future: _futureTrips,\n  builder: (context, snapshot) {\n    if (snapshot.connectionState\n      == ConnectionState.waiting)\n      return CircularProgressIndicator();\n    if (snapshot.hasError)\n      return _buildErrorWidget();\n    return ListView.builder(...);\n  }\n)',
        'function': 'Tu dong quan ly trang thai giao dien khi goi API: dang tai (loading), loi (error), thanh cong (danh sach)',
        'ui_note': 'Hien vong quay khi loading, thong bao loi neu mat mang, danh sach chuyen neu thanh cong'
    },
    {
        'name': 'Card (Trip Result Item)',
        'code': 'GestureDetector(\n  onTap: () =>\n    context.push("/trip/${trip.id}"),\n  child: Container(\n    decoration: BoxDecoration(\n      color: Colors.white,\n      borderRadius:\n        BorderRadius.circular(16)\n    ),\n    child: Row(children: [\n      Column(...), // Thong tin chuyen\n      Column(...), // Gia va nut Chon\n    ])\n  )\n)',
        'function': 'Moi the la 1 chuyen xe, gom: ten nha xe, gio khai hanh, gio den, con ghe trong, gia tien. Nhan vao chuyen sang trang chi tiet',
        'ui_note': 'The trang bo goc, thong tin chuyen trai - gia va so ghe phai'
    },
    {
        'name': 'FilterBar (Thanh loc)',
        'code': 'Row(children: [\n  FilterChip(\n    label: Text("Gia tang dan"),\n    onSelected: (v) => _sort(v)\n  ),\n  FilterChip(\n    label: Text("Con ghe"),\n    onSelected: (v) => _filter(v)\n  ),\n])',
        'function': 'Cac chip loc ket qua theo gia tang/giam dan va loc theo so ghe trong, thay doi ket qua theo thoi gian thuc',
        'ui_note': 'Cac nhan nho o dau danh sach, nhan vao de bat/tat che do loc'
    },
])

# =============================================
# 5. MAN HINH CHI TIET CHUYEN DI
# =============================================
add_section_title(doc, '5. MAN HINH CHI TIET CHUYEN DI (Trip Detail)')

add_widget_table(doc, 'Class: TripDetailScreen | Route: /trip/:id', [
    {
        'name': 'AppBar',
        'code': 'AppBar(\n  backgroundColor: Colors.white,\n  leading: IconButton(\n    icon: Icon(Icons.arrow_back),\n    onPressed: () => context.pop()\n  ),\n  title: Text("Chi tiet chuyen di"),\n  actions: [\n    IconButton(\n      icon: Icon(Icons.more_vert))\n  ]\n)',
        'function': 'Thanh tieu de trang, co nut quay lai (pop ra stack) va menu 3 cham',
        'ui_note': 'Thanh trang phia tren, nut mui ten lui goc trai, tieu de giua, dau 3 cham phai'
    },
    {
        'name': 'Container (Company Info Card)',
        'code': 'Container(\n  decoration: BoxDecoration(\n    color: Colors.white,\n    borderRadius: BorderRadius.circular(16)\n  ),\n  child: Row(children: [\n    Container( // Logo avatar\n      child: Text(companyInitials)\n    ),\n    Column(children: [\n      Text(trip.companyName),\n      Row(children: [\n        Icon(Icons.star),\n        Text("4.8 (320 danh gia)")\n      ])\n    ])\n  ])\n)',
        'function': 'The thong tin nha xe: logo chu cai, ten nha xe va diem danh gia sao lay tu backend',
        'ui_note': 'The trang, logo vuong xanh goc trai, ten va sao danh gia phia phai'
    },
    {
        'name': 'IntrinsicHeight + Row (Timeline)',
        'code': 'IntrinsicHeight(\n  child: Row(\n    crossAxisAlignment:\n      CrossAxisAlignment.stretch,\n    children: [\n      Column(children: [\n        // Diem tron dau tien\n        Container(width:1), // Duong thang\n        // Diem tron cuoi\n      ]),\n      Column(children: [\n        Text("${trip.departureTime}"),\n        Text("${trip.arrivalTime}"),\n      ])\n    ]\n  )\n)',
        'function': 'Ve duong ke thoi gian hanh trinh (Timeline). IntrinsicHeight lam cho duong ke doc tu dong dai bang chieu cao noi dung ben canh',
        'ui_note': 'Duong thang doc co 2 vong tron 2 dau, ben canh la gio khai hanh va gio den'
    },
    {
        'name': 'Row - Wrap (Amenities)',
        'code': 'Row(\n  mainAxisAlignment:\n    MainAxisAlignment.spaceAround,\n  children: [\n    _buildAmenity(\n      Icons.wifi, "WiFi mien phi"),\n    _buildAmenity(\n      Icons.ac_unit, "Dieu hoa"),\n    _buildAmenity(\n      Icons.water_drop, "Nuoc uong"),\n    _buildAmenity(\n      Icons.bed, "Chan goi"),\n  ]\n)',
        'function': 'Hien thi 4 tien ich cua xe (WiFi, dieu hoa, nuoc, chan goi) bang icon va chu nho bang nhau',
        'ui_note': '4 icon va chu nho xep ngang deu nhau trong khoi Tien ich chuyen xe'
    },
    {
        'name': 'Container (Sticky Bottom Bar)',
        'code': 'Container(\n  padding: EdgeInsets.all(16),\n  decoration: BoxDecoration(\n    color: Colors.white,\n    border: Border(top: BorderSide(\n      color: Color(0xFF3B82F6)))\n  ),\n  child: Row(\n    mainAxisAlignment:\n      MainAxisAlignment.spaceBetween,\n    children: [\n      Column(children: [\n        Text("Tong cong (1 ve)"),\n        Text(fmt.format(trip.price))\n      ]),\n      ElevatedButton(\n        onPressed: () => context.push(\n          "/seat_selection",\n          extra: trip),\n        child: Text("Chon ghe")\n      )\n    ]\n  )\n)',
        'function': 'Thanh toan cuoi trang luon co dinh o day man hinh. Hien gia ve thuc tu backend. Nut "Chon ghe" truyen du lieu Trip sang man hinh chon ghe',
        'ui_note': 'Thanh trang duoi cung, duong ke xanh phia tren, gia tien trai - nut den phai'
    },
])

# =============================================
# 6. MAN HINH CHON GHE
# =============================================
add_section_title(doc, '6. MAN HINH CHON GHE (Seat Selection)')

add_widget_table(doc, 'Class: SeatSelectionScreen | Route: /seat_selection', [
    {
        'name': 'GridView (So do ghe)',
        'code': 'GridView.builder(\n  gridDelegate:\n    SliverGridDelegateWithFixedCrossAxisCount(\n      crossAxisCount: 4,\n      childAspectRatio: 1.0\n    ),\n  itemBuilder: (context, index) {\n    final seatId = seatList[index];\n    final isBooked =\n      bookedSeats.contains(seatId);\n    return GestureDetector(\n      onTap: isBooked ? null\n        : () => _selectSeat(seatId),\n      child: _buildSeatWidget(seatId)\n    );\n  }\n)',
        'function': 'Hien thi so do ghe dang luoi 4 cot. Ghe da dat mau xam khong nhan duoc, ghe trong mau xanh nhat, ghe dang chon mau xanh dam',
        'ui_note': 'So do ghe chia hang, mau sac phan biet trang thai: xam=da dat, xanh=con trong, dam=dang chon'
    },
    {
        'name': 'Row (Legend - Chu thich)',
        'code': 'Row(children: [\n  _buildLegend(\n    Color(0xFFE2E8F0), "Da dat"),\n  _buildLegend(\n    Color(0xFFDCFCE7), "Con trong"),\n  _buildLegend(\n    Color(0xFF00639B), "Dang chon"),\n])',
        'function': 'Hang chu thich mau sac ghe, giup nguoi dung hieu y nghia tung mau tren so do',
        'ui_note': 'Hang 3 mau nho voi chu giai thich o phia tren so do ghe'
    },
])

# =============================================
# 7. MAN HINH VE CUA TOI
# =============================================
add_section_title(doc, '7. MAN HINH VE CUA TOI (My Tickets)')

add_widget_table(doc, 'Class: MyTicketsScreen | Route: /tickets', [
    {
        'name': 'TabBar + TabBarView',
        'code': 'TabController(\n  length: 3, vsync: this),\nTabBar(tabs: [\n  Tab(text: "Tat ca"),\n  Tab(text: "Cho thanh toan"),\n  Tab(text: "Da huy"),\n]),\nTabBarView(children: [\n  _buildList(_filterByTab(0)),\n  _buildList(_filterByTab(1)),\n  _buildList(_filterByTab(2)),\n])',
        'function': 'Bo 3 tab loc ve: Tat ca / Cho thanh toan / Da huy. Vuot ngang de chuyen tab, du lieu lay tu API /bookings',
        'ui_note': 'Thanh tab o phia tren, gach chan tab dang chon, vuot trai phai de chuyen'
    },
    {
        'name': 'Container (Booking Card)',
        'code': 'Container(\n  decoration: BoxDecoration(\n    color: Colors.white,\n    borderRadius: BorderRadius.circular(12)\n  ),\n  child: Column(children: [\n    Row(children: [\n      Text(route),      // Tuyen xe\n      StatusBadge(b),   // Trang thai\n    ]),\n    Text(dateTime),    // Ngay gio\n    Divider(),\n    Row(children: [\n      Text(seatInfo),   // Ghe\n      Text(price),      // Gia tien\n      PayButton(b)      // Nut thanh toan\n    ])\n  ])\n)',
        'function': 'Moi the hien thi 1 ve da dat: tuyen xe, ngay gio, so ghe, gia tien va nut thanh toan neu chua tra tien',
        'ui_note': 'The trang bo goc, co nhan trang thai mau (vang/xanh/do), co nut Thanh toan neu chua tra'
    },
])

# =============================================
# 8. MAN HINH THONG BAO
# =============================================
add_section_title(doc, '8. MAN HINH THONG BAO (Notifications)')

add_widget_table(doc, 'Class: NotificationsScreen | Route: /notifications', [
    {
        'name': 'RefreshIndicator + ListView.separated',
        'code': 'RefreshIndicator(\n  onRefresh: _loadNotifications,\n  child: ListView.separated(\n    padding: EdgeInsets.all(16),\n    itemCount: _notifications.length,\n    separatorBuilder: (ctx, i) =>\n      SizedBox(height: 12),\n    itemBuilder: (ctx, i) {\n      return _buildNotificationItem(\n        _notifications[i]);\n    }\n  )\n)',
        'function': 'Danh sach thong bao lay tu API /api/v1/notifications. Keo xuong de lam moi danh sach. separatorBuilder tao khoang cach giua cac item',
        'ui_note': 'Danh sach the thong bao, keo xuong o danh sach de refresh'
    },
    {
        'name': 'Container + Row (Notification Item)',
        'code': 'ClipRRect(\n  borderRadius: BorderRadius.circular(12),\n  child: IntrinsicHeight(\n    child: Row(children: [\n      Container(width: 4, // Duong vien mau\n        color: indicatorColor),\n      Padding(child: Row(children: [\n        // Icon tron\n        Column(children: [\n          Row([Text(title), Text(time)]),\n          Text(content)\n        ])\n      ]))\n    ])\n  )\n)',
        'function': 'Moi the thong bao co duong vien mau ben trai (xanh=chua doc), icon phan loai (thanh cong/khuyen mai/nhac nho/he thong), tieu de va noi dung',
        'ui_note': 'The trang, 4px mau ben trai khi chua doc, icon tron - tieu de dam - noi dung nho - thoi gian'
    },
])

# =============================================
# 9. MAN HINH TAI KHOAN
# =============================================
add_section_title(doc, '9. MAN HINH TAI KHOAN (Profile)')

add_widget_table(doc, 'Class: ProfileScreen | Route: /profile', [
    {
        'name': 'Stack (Avatar voi nut camera)',
        'code': 'Stack(\n  children: [\n    CircleAvatar(\n      radius: 48,\n      backgroundColor:\n        Color(0xFF0B192C),\n      child: Text(initials)\n    ),\n    Positioned(\n      bottom: 0, right: 0,\n      child: Container(\n        decoration: BoxDecoration(\n          color: Color(0xFF00639B),\n          shape: BoxShape.circle),\n        child: Icon(Icons.camera_alt)\n      )\n    )\n  ]\n)',
        'function': 'Anh dai dien hinh tron chua chu cai ten nguoi dung. Stack cho phep chong nut camera len tren goc phai anh',
        'ui_note': 'Vong tron xanh dam chua chu cai, nut camera nho mau xanh o goc phai duoi'
    },
    {
        'name': 'Column (Menu items)',
        'code': 'Column(children: [\n  _buildMenuItem(\n    Icons.history,\n    "Lich su chuyen di",\n    () => context.push(\n      "/trip-history")),\n  _buildMenuItem(\n    Icons.article_outlined,\n    "Dieu khoan su dung",\n    () => context.push("/terms")),\n  ...\n])',
        'function': 'Danh sach menu cai dat, moi dong la 1 GestureDetector + Row (icon - chu - mui ten). Nhan vao tung muc de dieu huong toi man hinh tuong ung',
        'ui_note': 'Danh sach hang doc cac muc cai dat, moi muc co icon trai - chu giua - mui ten phai'
    },
    {
        'name': 'TextButton (Dang xuat)',
        'code': 'TextButton(\n  onPressed: () async {\n    await context\n      .read<AuthService>()\n      .logout();\n    context.go("/login");\n  },\n  child: Text("Dang xuat",\n    style: TextStyle(\n      color: Color(0xFFEF4444)))\n)',
        'function': 'Goi ham logout() cua AuthService de xoa token khoi SecureStorage, sau do chuyen nguoi dung ve man hinh dang nhap',
        'ui_note': 'Chu "Dang xuat" mau do o cuoi danh sach menu'
    },
])

# =============================================
# 10. MAN HINH LICH SU CHUYEN DI
# =============================================
add_section_title(doc, '10. MAN HINH LICH SU CHUYEN DI (Trip History)')

add_widget_table(doc, 'Class: TripHistoryScreen | Route: /trip-history', [
    {
        'name': 'ListView.separated (Month Filter)',
        'code': 'SizedBox(\n  height: 32,\n  child: ListView.separated(\n    scrollDirection: Axis.horizontal,\n    itemCount: _months.length,\n    itemBuilder: (ctx, index) {\n      return GestureDetector(\n        onTap: () => setState(() =>\n          _selectedMonthIndex = index),\n        child: Container(\n          decoration: BoxDecoration(\n            color: isSelected\n              ? Color(0xFF00639B)\n              : Colors.white,\n          )\n        )\n      );\n    }\n  )\n)',
        'function': 'Danh sach thang cuon ngang (6 thang gan nhat tu hien tai). Nhan vao tung thang de loc danh sach chuyen di theo thang tuong ung',
        'ui_note': 'Hang chip cuon ngang phia tren, chip chon duoc to xanh, chip khac vien xam'
    },
    {
        'name': 'Container (Summary Card - Tong ket)',
        'code': 'Container(\n  decoration: BoxDecoration(\n    color: Color(0xFF0F172A), // Mau dark\n    borderRadius: BorderRadius.circular(12)\n  ),\n  child: Row(\n    mainAxisAlignment:\n      MainAxisAlignment.spaceBetween,\n    children: [\n      Column(children:[\n        Text("Tong chuyen di"),\n        Text("$totalTrips Chuyen")\n      ]),\n      Column(children:[\n        Text("Tong chi tieu"),\n        Text(currencyFormatter\n          .format(totalSpent))\n      ])\n    ]\n  )\n)',
        'function': 'The tong ket mau den: tu dong dem so chuyen va tinh tong tien chi tieu theo thang dang chon tu du lieu API',
        'ui_note': 'The nen den, trai: so chuyen, phai: tong tien - du lieu tu dong tinh tu backend'
    },
    {
        'name': 'Column (Trip History Card)',
        'code': 'Container(\n  child: Column(children: [\n    Row(children: [\n      Column(children: [\n        Text(route),      // Tuyen xe\n        Text(company),    // Nha xe\n        Text(date),       // Ngay\n      ]),\n      Column(children: [\n        StatusBadge(),    // Hoan thanh/Huy\n        Text(price),      // Gia tien\n      ])\n    ]),\n    Divider(),\n    Row(children: [\n      // Chua co danh gia: nut "Danh gia"\n      // Da danh gia: hien sao\n    ])\n  ])\n)',
        'function': 'Moi the la 1 chuyen di da thuc hien: tuyen, nha xe, ngay, gia, trang thai. Phan duoi co nut danh gia hoac hien sao da danh gia',
        'ui_note': 'The trang, phan tren thong tin chuyen, ke ngang, phan duoi: nut Danh gia hoac 5 sao'
    },
])

# =============================================
# 11. MAN HINH DIEU KHOAN
# =============================================
add_section_title(doc, '11. MAN HINH DIEU KHOAN SU DUNG (Terms)')

add_widget_table(doc, 'Class: TermsScreen | Route: /terms', [
    {
        'name': 'SingleChildScrollView + Column',
        'code': 'SingleChildScrollView(\n  padding: EdgeInsets.all(20),\n  child: Column(\n    crossAxisAlignment:\n      CrossAxisAlignment.start,\n    children: [\n      Text("1. Chap nhan dieu khoan",\n        style: TextStyle(\n          fontWeight: FontWeight.w700)),\n      Text(content),\n      SizedBox(height: 20),\n      Text("2. Dich vu dat ve",\n        style: TextStyle(\n          fontWeight: FontWeight.w700)),\n      Text(content),\n      ...\n    ]\n  )\n)',
        'function': 'Man hinh van ban thuan tuy, SingleChildScrollView cho phep cuon khi noi dung dai hon man hinh, Column sap xep cac muc theo hang doc',
        'ui_note': 'Trang trang don gian, tieu de muc in dam, noi dung xam nhat, cuon doc de doc toan bo'
    },
])

doc.save('PhanTich_Widget_UI_v2.docx')
