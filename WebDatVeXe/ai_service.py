import re
import unicodedata
from datetime import date, datetime, timedelta
from difflib import SequenceMatcher


class AIService:
    def __init__(self):
        self.persona = {
            "name": "Em",
            "brand": "HUTECH BUS",
            "hotline": "1900 1234",
            "bus_types": "Limousine, Cabin/Phòng và Giường nằm"
        }

        self.location_aliases = {
            "TP. Hồ Chí Minh": [
                "tp hcm", "tphcm", "hcm", "sai gon", "saigon", "sg", "ho chi minh", "tp ho chi minh", "tp hồ chí minh",
                "hcmc", "tpho chi minh", "tp.hcm", "tp.ho chi minh", "sgon"
            ],
            "Đà Lạt": ["da lat", "đà lạt", "dalat", "dl"],
            "Nha Trang": ["nha trang", "nt"],
            "Đà Nẵng": ["da nang", "đà nẵng", "danang", "dn"],
            "Hà Nội": ["ha noi", "hanoi", "hn", "hà nội", "ha noii", "ha hoi", "ha noii", "ha nọi"],
            "Cần Thơ": ["can tho", "cần thơ", "ct"],
            "Vũng Tàu": ["vung tau", "vũng tàu", "vt"],
            "Bà Rịa - Vũng Tàu": ["ba ria vung tau", "bà rịa vũng tàu", "brvt", "ba ria", "bà rịa", "vung tau", "vũng tàu"],
            "Đắk Lắk": ["dak lak", "đắk lắk", "daklak", "dak lakk", "dlk"],
            "Đak Mil": ["dak mil", "đak mil", "dm"],
            "Đak Đoa": ["dak doa", "đak đoa"],
            "Gia Lai": ["gia lai", "gl"],
            "Gia Nghĩa": ["gia nghia", "gia nghĩa", "gn"],
            "Cư Jut": ["cu jut", "cư jut", "cujut", "cj"],
            "Bạc Liêu": ["bac lieu", "bạc liêu", "bl"]
        }

        self.number_words = {
            "mot": 1, "một": 1, "1": 1,
            "hai": 2, "2": 2,
            "ba": 3, "3": 3,
            "bon": 4, "bốn": 4, "4": 4,
            "nam": 5, "năm": 5, "5": 5,
            "sau": 6, "sáu": 6, "6": 6,
            "bay": 7, "bảy": 7, "7": 7,
            "tam": 8, "tám": 8, "8": 8,
            "chin": 9, "chín": 9, "9": 9,
            "muoi": 10, "mười": 10, "10": 10,
        }

        self.weekday_aliases = {
            0: ["thu 2", "thứ 2", "t2", "thu hai", "thứ hai"],
            1: ["thu 3", "thứ 3", "t3", "thu ba", "thứ ba"],
            2: ["thu 4", "thứ 4", "t4", "thu tu", "thứ tư"],
            3: ["thu 5", "thứ 5", "t5", "thu nam", "thứ năm"],
            4: ["thu 6", "thứ 6", "t6", "thu sau", "thứ sáu"],
            5: ["thu 7", "thứ 7", "t7", "thu bay", "thứ bảy"],
            6: ["chu nhat", "chủ nhật", "cn"]
        }

        self.route_connectors = ["di", "den", "toi", "ra", "vao", "len", "xuong", "ve"]
        self.location_stop_words = {
            "di", "den", "toi", "ra", "vao", "len", "xuong", "ve", "tu", "o", "tai", "luc", "khoang", "ngay",
            "mai", "nay", "mot", "hom", "hien", "gio", "ghe", "ve", "nguoi", "khach", "xe", "chuyen", "book",
            "dat", "luon", "cho", "toi", "em", "anh", "chi", "buoi", "sang", "chieu", "toi", "dem", "khuya"
        }

    def normalize_text(self, text):
        if not text:
            return ""
        text = str(text).strip().lower()
        text = text.replace('đ', 'd').replace('Đ', 'D')
        text = unicodedata.normalize("NFD", text)
        text = "".join(ch for ch in text if unicodedata.category(ch) != "Mn")
        text = re.sub(r"[^\w\s:/\-→>]", " ", text)
        return re.sub(r"\s+", " ", text).strip()

    def _unique_normalized(self, values):
        seen = set()
        result = []
        for value in values:
            key = self.normalize_text(value)
            if key and key not in seen:
                result.append(value)
                seen.add(key)
        return result

    def _location_variants_for(self, canonical, available_locations):
        variants = [canonical]
        variants.extend(self.location_aliases.get(canonical, []))

        normalized_canonical = self.normalize_text(canonical)
        for known, aliases in self.location_aliases.items():
            known_n = self.normalize_text(known)
            alias_ns = {self.normalize_text(alias) for alias in aliases}
            if known_n == normalized_canonical or normalized_canonical in alias_ns:
                variants.extend([known] + aliases)

        return self._unique_normalized(variants)

    def _iter_location_dictionary(self, available_locations):
        items = []
        for location in available_locations:
            for variant in self._location_variants_for(location, available_locations):
                items.append({
                    "canonical": location,
                    "variant": variant,
                    "variant_n": self.normalize_text(variant)
                })
        items.sort(key=lambda item: len(item["variant_n"]), reverse=True)
        return items

    def human_bus_type(self, bus_type):
        if not bus_type:
            return "Không rõ loại xe"
        value = self.normalize_text(bus_type)
        if "limo" in value or "vip" in value:
            return "Limousine"
        if "cabin" in value or "phong" in value or "luxury" in value:
            return "Cabin/Phòng"
        if "sleeper" in value or "giuong" in value:
            return "Giường nằm"
        if "seat" in value or "ghe" in value:
            return "Ghế ngồi"
        return bus_type.replace("_", " ").title()

    def detect_reset(self, text):
        text = self.normalize_text(text)
        keywords = [
            "lam lai", "làm lại", "dat lai", "đặt lại", "reset", "xoa thong tin",
            "xóa thông tin", "bat dau lai", "bắt đầu lại", "nhap lai", "nhập lại"
        ]
        return any(k in text for k in keywords)

    def detect_greeting(self, text):
        text = self.normalize_text(text)
        return text in {"hi", "hello", "alo", "ad", "admin"} or any(k in text for k in ["xin chao", "chao", "chào"])

    def detect_ticket_lookup(self, text):
        text = self.normalize_text(text)
        return any(k in text for k in ["ve cua toi", "vé của tôi", "xem ve", "xem vé", "my tickets", "ve toi", "vé tôi"])

    def detect_booking_interest(self, text, state=None):
        text = self.normalize_text(text)
        if state and any(state.get(k) for k in ["from", "to", "date_iso", "pax"]):
            return True
        keywords = [
            "dat ve", "đặt vé", "tim chuyen", "tìm chuyến", "mua ve", "mua vé", "book",
            "khoi hanh", "khởi hành", "di ", "đi ", "chuyen", "chuyến", "ve xe", "vé xe"
        ]
        return any(k in text for k in keywords)

    def parse_passengers(self, text):
        raw = text or ""
        normalized = self.normalize_text(raw)

        compact = re.search(r"\b(\d{1,2})\s*(?:v|ve|ng|nguoi|kh|khach|ghe|cho)\b", normalized)
        if compact:
            return max(1, int(compact.group(1)))

        match = re.search(r"\b(\d{1,2})\s*(?:nguoi|ve|ghe|cho|khach)\b", normalized)
        if match:
            return max(1, int(match.group(1)))

        if re.fullmatch(r"\d{1,2}", normalized):
            return max(1, int(normalized))

        for word, value in self.number_words.items():
            if re.search(rf"\b{re.escape(word)}\s*(?:nguoi|ve|ghe|cho|khach)?\b", normalized):
                return value
        return None

    def parse_time_pref(self, text):
        raw = (text or '').strip().lower()
        normalized = self.normalize_text(text)

        explicit = re.search(r"\b(\d{1,2})[:hg](\d{1,2})\b", normalized)
        if explicit:
            hour = int(explicit.group(1))
            minute = int(explicit.group(2))
            if 0 <= hour <= 23 and 0 <= minute <= 59:
                return {"label": f"{hour:02d}:{minute:02d}", "minutes": hour * 60 + minute, "bucket": None}

        compact = re.search(r"\b(\d{1,2})\s*(?:gio|giờ|h)\b", normalized)
        if compact:
            hour = int(compact.group(1))
            if 0 <= hour <= 23:
                return {"label": f"{hour:02d}:00", "minutes": hour * 60, "bucket": None}

        if re.search(r"\b(?:buoi\s+sang|sang\s+som|sang)\b", normalized):
            return {"label": "buổi sáng", "minutes": 8 * 60, "bucket": "morning"}
        if re.search(r"\b(?:buoi\s+trua|trua)\b", normalized):
            return {"label": "buổi trưa", "minutes": 12 * 60, "bucket": "noon"}
        if re.search(r"\b(?:buoi\s+chieu|chieu)\b", normalized):
            return {"label": "buổi chiều", "minutes": 15 * 60, "bucket": "afternoon"}
        if re.search(r"\btối\b", raw) or 'buổi tối' in raw or re.search(r"\b(?:buoi\s+toi|toi\s+nay|toi\s+mai|dem|khuya)\b", normalized):
            return {"label": "buổi tối", "minutes": 19 * 60, "bucket": "evening"}
        return None

    def parse_bus_type(self, text):
        normalized = self.normalize_text(text)
        if any(k in normalized for k in ["limousine", "limo", "vip", "limo vip"]):
            return "limousine"
        if any(k in normalized for k in ["phong", "cabin", "giuong phong", "giường phòng", "luxury", "cab"]):
            return "cabin"
        if any(k in normalized for k in ["giuong", "giường", "sleeper"]):
            return "sleeper"
        if any(k in normalized for k in ["ghe", "ghế", "seat"]):
            return "seat"
        return None

    def _next_weekday(self, today, weekday_index):
        days_ahead = (weekday_index - today.weekday()) % 7
        return today + timedelta(days=days_ahead)

    def parse_date(self, text, today=None):
        today = today or date.today()
        raw = text or ""
        normalized = self.normalize_text(raw)

        if any(k in normalized for k in ["hom nay", "hôm nay", "nay"]):
            return {"date": today, "label": "hôm nay"}
        if any(k in normalized for k in ["ngay mai", "ngày mai", "mai"]):
            return {"date": today + timedelta(days=1), "label": "ngày mai"}
        if re.search(r"\b(?:mot|mốt)\b", normalized):
            return {"date": today + timedelta(days=2), "label": "ngày mốt"}
        if re.search(r"\bcuoi\s+tuan\b", normalized):
            target = self._next_weekday(today, 5)
            return {"date": target, "label": f"thứ 7 ({target.strftime('%d/%m/%Y')})"}

        for weekday_index, aliases in self.weekday_aliases.items():
            if any(re.search(rf"\b{re.escape(self.normalize_text(alias))}\b", normalized) for alias in aliases):
                target = self._next_weekday(today, weekday_index)
                label = aliases[0].upper().replace("THU", "Thứ").replace("CHU NHAT", "Chủ nhật")
                return {"date": target, "label": f"{label} ({target.strftime('%d/%m/%Y')})"}

        iso = re.search(r"\b(20\d{2})-(\d{1,2})-(\d{1,2})\b", normalized)
        if iso:
            try:
                year, month, day = map(int, iso.groups())
                parsed = date(year, month, day)
                return {"date": parsed, "label": parsed.strftime("%d/%m/%Y")}
            except ValueError:
                return None

        dmy = re.search(r"\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b", normalized)
        if dmy:
            try:
                day = int(dmy.group(1))
                month = int(dmy.group(2))
                year = dmy.group(3)
                if year:
                    year = int(year)
                    if year < 100:
                        year += 2000
                else:
                    year = today.year
                    if (month, day) < (today.month, today.day):
                        year += 1
                parsed = date(year, month, day)
                return {"date": parsed, "label": parsed.strftime("%d/%m/%Y")}
            except ValueError:
                return None

        long_form = re.search(r"ngay\s*(\d{1,2})\s*thang\s*(\d{1,2})(?:\s*nam\s*(\d{4}))?", normalized)
        if long_form:
            try:
                day = int(long_form.group(1))
                month = int(long_form.group(2))
                year = int(long_form.group(3)) if long_form.group(3) else today.year
                parsed = date(year, month, day)
                return {"date": parsed, "label": parsed.strftime("%d/%m/%Y")}
            except ValueError:
                return None
        return None

    def location_similarity(self, value, candidate):
        value_n = self.normalize_text(value)
        candidate_n = self.normalize_text(candidate)
        if not value_n or not candidate_n:
            return 0.0
        if value_n == candidate_n:
            return 1.0
        if value_n in candidate_n or candidate_n in value_n:
            return 0.96

        candidate_aliases = []
        for canonical, aliases in self.location_aliases.items():
            known_variants = [self.normalize_text(canonical)] + [self.normalize_text(a) for a in aliases]
            if candidate_n in known_variants:
                candidate_aliases = aliases + [canonical]
                break

        variants = [candidate]
        variants.extend(candidate_aliases)
        best = 0.0
        value_tokens = set(value_n.split())
        for variant in variants:
            variant_n = self.normalize_text(variant)
            ratio = SequenceMatcher(None, value_n, variant_n).ratio()
            best = max(best, ratio)
            variant_tokens = set(variant_n.split())
            if value_tokens and variant_tokens:
                overlap = len(value_tokens & variant_tokens) / max(len(value_tokens), len(variant_tokens))
                best = max(best, overlap)
        return best

    def best_location_match(self, raw_value, available_locations):
        best_location = None
        best_score = 0.0
        for candidate in available_locations:
            score = self.location_similarity(raw_value, candidate)
            if score > best_score:
                best_score = score
                best_location = candidate
        return best_location, best_score

    def canonicalize_location(self, raw_value, available_locations, min_score=0.6, fallback_raw=True):
        if not raw_value:
            return None
        best_location, best_score = self.best_location_match(raw_value, available_locations)
        if best_location and best_score >= min_score:
            return best_location
        return raw_value.strip() if fallback_raw else None

    def _looks_like_location_phrase(self, phrase):
        phrase_n = self.normalize_text(phrase)
        if not phrase_n:
            return False
        if re.search(r"\d", phrase_n):
            return False
        if phrase_n in self.location_stop_words:
            return False
        if len(phrase_n) <= 1:
            return False
        return True

    def _accept_exact_variant(self, text_n, variant_n):
        pattern = rf"(?<!\w){re.escape(variant_n)}(?!\w)"
        return list(re.finditer(pattern, text_n))

    def extract_location_mentions(self, text, available_locations):
        normalized = self.normalize_text(text)
        if not normalized:
            return []

        mentions = []
        dictionary = self._iter_location_dictionary(available_locations)

        for item in dictionary:
            variant_n = item["variant_n"]
            if not variant_n:
                continue
            for match in self._accept_exact_variant(normalized, variant_n):
                mentions.append({
                    "location": item["canonical"],
                    "score": 0.99 if variant_n == self.normalize_text(item["canonical"]) else 0.97,
                    "start": match.start(),
                    "end": match.end(),
                    "text": normalized[match.start():match.end()]
                })

        token_spans = [(m.group(0), m.start(), m.end()) for m in re.finditer(r"\S+", normalized)]
        max_window = 4
        for i in range(len(token_spans)):
            for j in range(i, min(i + max_window, len(token_spans))):
                phrase_start = token_spans[i][1]
                phrase_end = token_spans[j][2]
                phrase = normalized[phrase_start:phrase_end]
                if not self._looks_like_location_phrase(phrase):
                    continue
                best_location, best_score = self.best_location_match(phrase, available_locations)
                if best_location and best_score >= 0.82:
                    mentions.append({
                        "location": best_location,
                        "score": best_score,
                        "start": phrase_start,
                        "end": phrase_end,
                        "text": phrase
                    })

        accepted = []
        occupied = []
        for mention in sorted(mentions, key=lambda item: (-item["score"], -(item["end"] - item["start"]), item["start"])):
            if mention["location"] is None:
                continue
            overlap = False
            for start, end, loc in occupied:
                if not (mention["end"] <= start or mention["start"] >= end):
                    overlap = True
                    if loc == mention["location"]:
                        overlap = True
                    break
            if overlap:
                continue
            accepted.append(mention)
            occupied.append((mention["start"], mention["end"], mention["location"]))

        accepted.sort(key=lambda item: item["start"])
        deduped = []
        seen = set()
        for mention in accepted:
            key = (self.normalize_text(mention["location"]), mention["start"], mention["end"])
            if key in seen:
                continue
            deduped.append(mention)
            seen.add(key)
        return deduped

    def extract_locations(self, text, available_locations):
        deduped = []
        seen = set()
        for mention in self.extract_location_mentions(text, available_locations):
            key = self.normalize_text(mention["location"])
            if key not in seen:
                deduped.append(mention["location"])
                seen.add(key)
        return deduped[:2]

    def _best_mention_before(self, mentions, position):
        candidates = [m for m in mentions if m["end"] <= position]
        if not candidates:
            return None
        return max(candidates, key=lambda m: (m["score"], -(position - m["end"])))

    def _best_mention_after(self, mentions, position):
        candidates = [m for m in mentions if m["start"] >= position]
        if not candidates:
            return None
        return max(candidates, key=lambda m: (m["score"], -(m["start"] - position)))

    def _best_location_in_fragment(self, fragment, available_locations):
        mentions = self.extract_location_mentions(fragment, available_locations)
        if mentions:
            return max(mentions, key=lambda item: item["score"])["location"]
        return self.canonicalize_location(fragment, available_locations, min_score=0.82, fallback_raw=False)

    def extract_route_slots(self, text, available_locations):
        normalized = self.normalize_text(text)
        result = {"from": None, "to": None}
        if not normalized:
            return result

        mentions = self.extract_location_mentions(text, available_locations)

        explicit_from = re.search(r"\btu\s+(.+?)(?=\b(?:di|den|toi|ra|vao|ve|len|xuong|ngay|mai|hom nay|luc|khoang|cho|\d|$))", normalized)
        if explicit_from:
            result["from"] = self._best_location_in_fragment(explicit_from.group(1), available_locations)

        explicit_to = re.search(r"\b(?:di|den|ra|vao|len|xuong|toi)\s+(.+?)(?=\b(?:tu|ngay|mai|hom nay|luc|khoang|cho|\d|$))", normalized)
        if explicit_to:
            possible_to = self._best_location_in_fragment(explicit_to.group(1), available_locations)
            if possible_to:
                result["to"] = possible_to

        connector_matches = list(re.finditer(r"\b(?:di|den|toi|ra|vao|len|xuong)\b|->|→|=>", normalized))
        for connector in connector_matches:
            before = self._best_mention_before(mentions, connector.start())
            after = self._best_mention_after(mentions, connector.end())
            if before and after and self.normalize_text(before["location"]) != self.normalize_text(after["location"]):
                result["from"] = result["from"] or before["location"]
                result["to"] = result["to"] or after["location"]
                break

        if (not result["from"] or not result["to"]) and len(mentions) >= 2:
            ordered_locations = []
            seen = set()
            for mention in mentions:
                key = self.normalize_text(mention["location"])
                if key not in seen:
                    ordered_locations.append(mention["location"])
                    seen.add(key)
            if len(ordered_locations) >= 2:
                result["from"] = result["from"] or ordered_locations[0]
                result["to"] = result["to"] or ordered_locations[1]

        if len(mentions) == 1:
            only_location = mentions[0]["location"]
            if not result["from"] and re.search(r"\btu\b", normalized):
                result["from"] = only_location
            elif not result["to"] and re.search(r"\b(?:di|den|toi|ra|vao|len|xuong)\b", normalized):
                result["to"] = only_location
            elif not result["to"] and not result["from"]:
                result["to"] = only_location

        if result["from"] and result["to"] and self.normalize_text(result["from"]) == self.normalize_text(result["to"]):
            result["to"] = None
        return result

    def extract_trip_selection(self, text):
        normalized = self.normalize_text(text)
        direct_index = re.search(r"(?:chon|chọn|trip|chuyen|chuyến|option|lay|lấy)?\s*(\d{1,2})$", normalized)
        if direct_index:
            return {"type": "index", "value": int(direct_index.group(1))}

        patterns = [
            (r"\b(?:chuyen|chuyến)?\s*dau(?:\s+tien)?\b", "first"),
            (r"\b(?:chuyen|chuyến)?\s*cuoi\b", "last"),
            (r"\b(?:re|rẻ)\s*nhat\b", "cheapest"),
            (r"\b(?:som|sớm)\s*nhat\b", "earliest"),
            (r"\b(?:muon|muộn|tre|trễ)\s*nhat\b", "latest"),
        ]
        for pattern, value in patterns:
            if re.search(pattern, normalized):
                return {"type": "strategy", "value": value}
        return None


    def _action_texts(self, action):
        values = []
        for key in ["label", "aria", "title", "placeholder", "name", "id", "form_label", "href"]:
            value = action.get(key) if isinstance(action, dict) else None
            if value:
                values.append(str(value))
        normalized = []
        seen = set()
        for value in values:
            key = self.normalize_text(value)
            if key and key not in seen:
                normalized.append(key)
                seen.add(key)
        return normalized

    def _strip_ui_words(self, normalized):
        text = f" {normalized} "
        phrases = [
            "vui long", "lam on", "giup toi", "giup minh", "giup em", "cho toi", "cho minh", "cho em",
            "hay", "nhe", "nha", "a", "di", "toi muon", "minh muon", "em muon", "anh muon", "chi muon",
            "bam vao", "bam nut", "bam", "nhan vao", "nhan nut", "nhan", "click vao", "click", "an vao", "an nut", "an",
            "mo trang", "mo muc", "mo", "vao trang", "vao muc", "vao", "di toi", "di den", "chuyen den",
            "chon", "xem", "cuon den", "keo den"
        ]
        for phrase in sorted(phrases, key=len, reverse=True):
            text = text.replace(f" {phrase} ", " ")
        return re.sub(r"\s+", " ", text).strip()

    def _score_action_label(self, target, action):
        target = self.normalize_text(target)
        if not target:
            return 0

        stop_words = {"nut", "muc", "trang", "vao", "bam", "nhan", "click", "chon", "xem", "mo", "toi", "minh", "em", "anh", "chi"}
        target_tokens = {token for token in target.split() if token not in stop_words}
        best = 0

        for text in self._action_texts(action):
            text_tokens = {token for token in text.split() if token not in stop_words}
            if not text_tokens:
                continue
            score = SequenceMatcher(None, target, text).ratio()
            if target == text:
                score = max(score, 1.0)
            elif target in text or text in target:
                shorter = min(len(target), len(text))
                longer = max(len(target), len(text)) or 1
                score = max(score, 0.78 + 0.18 * (shorter / longer))
            overlap = len(target_tokens & text_tokens) / max(1, len(target_tokens | text_tokens))
            score = max(score, overlap)
            if action.get("kind") == "submit" and any(k in target for k in ["gui", "luu", "xac nhan", "thanh toan", "dat ve", "tao"]):
                score += 0.08
            if action.get("kind") == "navigate" and any(k in target for k in ["trang", "muc", "vao", "mo", "xem"]):
                score += 0.04
            best = max(best, min(score, 1.0))
        return best

    def _best_action_match(self, target, actions, allowed_kinds=None, threshold=0.56):
        if not actions:
            return None, 0
        allowed = set(allowed_kinds or [])
        best_action = None
        best_score = 0
        for action in actions:
            if allowed and action.get("kind") not in allowed:
                continue
            score = self._score_action_label(target, action)
            if score > best_score:
                best_action = action
                best_score = score
        if best_score >= threshold:
            return best_action, best_score
        return None, best_score

    def _parse_fill_request(self, text):
        raw = (text or "").strip()
        normalized = self.normalize_text(raw)

        patterns = [
            r"(?:điền|dien|nhập|nhap|gõ|go)\s+(?:vào\s+)?(.+?)\s*(?:là|la|:|=)\s*(.+)$",
            r"(?:đặt|dat)\s+(.+?)\s*(?:là|la|:|=)\s*(.+)$",
        ]
        for pattern in patterns:
            match = re.search(pattern, raw, flags=re.IGNORECASE)
            if match:
                return match.group(1).strip(), match.group(2).strip()

        field_aliases = [
            ("email", ["email", "mail", "gmail"]),
            ("mat khau", ["mat khau", "password"]),
            ("so dien thoai", ["so dien thoai", "sdt", "dien thoai", "phone"]),
            ("ho ten", ["ho ten", "ten", "name"]),
            ("ngay di", ["ngay di", "ngay khoi hanh", "date"]),
            ("diem don", ["diem don", "noi don", "pickup"]),
            ("diem tra", ["diem tra", "noi tra", "dropoff"]),
        ]
        for canonical, aliases in field_aliases:
            for alias in aliases:
                match = re.search(rf"\b{re.escape(alias)}\b\s*(?:cua toi|của tôi)?\s*(?:la|là|:|=)\s*(.+)$", normalized)
                if match:
                    # Với email/số điện thoại, bản normalize vẫn giữ ký tự quan trọng. Với tên riêng,
                    # người dùng nên dùng mẫu "điền họ tên là ..." để giữ nguyên dấu tiếng Việt.
                    return canonical, match.group(1).strip()
        return None

    def _direct_navigation_action(self, normalized):
        shortcuts = [
            (["dang nhap nha xe", "dang nhap cong ty", "login nha xe", "login cong ty"], "/company/login", "trang đăng nhập nhà xe"),
            (["dang ky nha xe", "dang ky cong ty", "mo tai khoan nha xe"], "/company/register", "trang đăng ký nhà xe"),
            (["dang nhap nhan vien", "login nhan vien", "nhan vien dang nhap"], "/staff/login", "trang đăng nhập nhân viên"),
            (["dang nhap", "login"], "/passenger/login", "trang đăng nhập"),
            (["dang ky", "tao tai khoan", "register"], "/passenger/register", "trang đăng ký"),
            (["quen mat khau", "lay lai mat khau"], "/forgot-password", "trang quên mật khẩu"),
            (["ve cua toi", "ve toi", "my tickets", "lich su ve"], "/my-tickets", "trang Vé của tôi"),
            (["ho so", "tai khoan cua toi", "profile", "thong tin ca nhan"], "/profile", "trang hồ sơ"),
            (["quan ly", "admin", "cong quan ly", "bang dieu khien"], "/admin", "cổng quản lý"),
            (["trang chu", "home", "ve dau trang"], "/", "trang chủ"),
            (["tim chuyen", "tim ve", "dat ve", "mua ve"], "/#bt-search", "mục tìm chuyến"),
            (["dich vu", "tien ich"], "/#bt-features", "mục dịch vụ"),
            (["diem den", "dia diem", "tuyen pho bien"], "/#bt-destinations", "mục điểm đến"),
            (["lien he", "hotline", "ho tro"], "/#bt-contact", "mục liên hệ"),
            (["chinh sach bao mat", "bao mat"], "/privacy", "chính sách bảo mật"),
            (["dieu khoan", "dieu khoan su dung"], "/terms", "điều khoản sử dụng"),
            (["dang xuat", "logout", "thoat tai khoan"], "/logout", "đăng xuất"),
        ]
        for aliases, url, label in shortcuts:
            if any(alias in normalized for alias in aliases):
                return {
                    "response": f"Dạ em mở {label} cho mình nhé.",
                    "action": {"type": "navigate", "url": url, "label": label}
                }
        return None

    def resolve_ui_action(self, message, page_actions=None, current_path=None):
        """Map natural-language UI requests to a safe front-end action.

        The browser sends only currently visible controls. The server picks the
        best matching control and returns an action for the browser to execute;
        this keeps the chatbot generic enough to operate new buttons without
        hard-coding every page template.
        """
        normalized = self.normalize_text(message)
        if not normalized:
            return None

        page_actions = [a for a in (page_actions or []) if isinstance(a, dict) and a.get("selector")]

        fill_request = self._parse_fill_request(message)
        if fill_request:
            field_query, value = fill_request
            fields = [a for a in page_actions if a.get("kind") == "field"]
            action, _ = self._best_action_match(field_query, fields, threshold=0.42)
            if action:
                label = action.get("label") or field_query
                return {
                    "response": f"Dạ em đã điền ô “{label}” cho mình.",
                    "action": {
                        "type": "fill",
                        "selector": action.get("selector"),
                        "value": value,
                        "label": label
                    }
                }

        seat_match = re.search(r"\bghe\s*([a-z]{0,2}\d{1,3}[a-z]{0,2}|[a-z]\d{1,3})\b", normalized)
        if seat_match:
            seat_code = seat_match.group(1).upper()
            seats = [a for a in page_actions if a.get("kind") == "seat"]
            action, _ = self._best_action_match(f"ghe {seat_code}", seats, threshold=0.52)
            if action:
                return {
                    "response": f"Dạ em chọn ghế {seat_code} cho mình.",
                    "action": {"type": "click", "selector": action.get("selector"), "label": action.get("label") or seat_code}
                }

        # Chỉ tự thao tác nút/link khi câu có ý định điều khiển giao diện rõ ràng.
        ui_verbs = [
            "bam", "nhan", "click", "an nut", "an vao", "mo", "vao", "di toi", "di den", "chuyen den",
            "chon", "xem", "cuon", "keo den", "scroll"
        ]
        has_ui_verb = any(verb in normalized for verb in ui_verbs)

        shortcut = self._direct_navigation_action(normalized)

        if not has_ui_verb:
            # Nếu người dùng chỉ nói "tìm chuyến sg dl mai 2v" thì để luồng tìm chuyến AI xử lý,
            # không chuyển về khu vực tìm kiếm. Các shortcut khác như "đăng nhập" hoặc "vé của tôi"
            # vẫn có thể được mở trực tiếp.
            if shortcut and not any(k in normalized for k in ["tim chuyen", "dat ve", "mua ve", "tim ve"]):
                return shortcut
            return None

        if any(k in normalized for k in ["cuon", "keo den", "scroll"]):
            if shortcut:
                shortcut["action"]["type"] = "scroll"
                return shortcut

        target = self._strip_ui_words(normalized) or normalized
        action, score = self._best_action_match(target, page_actions, threshold=0.56)
        if action:
            label = action.get("label") or target
            if action.get("kind") == "field":
                return {
                    "response": f"Dạ em đưa con trỏ tới ô “{label}”. Nếu muốn điền nhanh, anh/chị nhắn: điền {label} là ...",
                    "action": {"type": "click", "selector": action.get("selector"), "label": label}
                }
            return {
                "response": f"Dạ em sẽ thao tác “{label}” cho mình.",
                "action": {"type": "click", "selector": action.get("selector"), "label": label}
            }

        if shortcut:
            return shortcut

        return None

    def parse_message(self, message, state, available_locations):
        parsed = {
            "reset": self.detect_reset(message),
            "greeting": self.detect_greeting(message),
            "show_tickets": self.detect_ticket_lookup(message),
            "booking_interest": self.detect_booking_interest(message, state),
            "selection": self.extract_trip_selection(message),
            "slots": {
                "from": None,
                "to": None,
                "date_iso": None,
                "date_label": None,
                "pax": None,
                "time_pref": None,
                "bus_type": None
            }
        }

        route_slots = self.extract_route_slots(message, available_locations)
        parsed["slots"].update(route_slots)

        date_info = self.parse_date(message)
        if date_info:
            parsed["slots"]["date_iso"] = date_info["date"].isoformat()
            parsed["slots"]["date_label"] = date_info["label"]

        pax = self.parse_passengers(message)
        if pax:
            parsed["slots"]["pax"] = pax

        time_pref = self.parse_time_pref(message)
        if time_pref:
            parsed["slots"]["time_pref"] = time_pref

        bus_type = self.parse_bus_type(message)
        if bus_type:
            parsed["slots"]["bus_type"] = bus_type

        return parsed

    def merge_state(self, state, parsed_slots):
        new_state = dict(state)
        criteria_changed = False
        for key, value in parsed_slots.items():
            if value is None:
                continue
            if new_state.get(key) != value:
                criteria_changed = True
                new_state[key] = value
        if criteria_changed:
            new_state["trip_options"] = []
        return new_state, criteria_changed

    def booking_ready(self, state):
        return bool(state.get("from") and state.get("to") and state.get("date_iso") and state.get("pax"))

    def next_question(self, state):
        if not state.get("from"):
            return "Dạ mình muốn xuất phát từ đâu ạ? Ví dụ: TP.HCM, Hà Nội, Đà Lạt..."
        if not state.get("to"):
            return "Dạ mình muốn đi đến đâu ạ?"
        if not state.get("date_iso"):
            return "Dạ mình muốn khởi hành vào ngày nào ạ? Ví dụ: hôm nay, ngày mai, thứ 6 hoặc 15/04."
        if not state.get("pax"):
            return "Dạ mình đi mấy người ạ? Ví dụ: 2 vé hoặc 3 người."
        return "Dạ mình muốn đi khung giờ nào ạ? Ví dụ: sáng, chiều, tối hoặc 18:30."

    def format_trip_options(self, state, trips):
        header = (
            f"Dạ em tìm được {len(trips)} chuyến phù hợp cho tuyến {state['from']} → {state['to']} "
            f"vào {state.get('date_label') or state['date_iso']}"
        )
        if state.get("time_pref"):
            header += f", ưu tiên {state['time_pref']['label']}"
        header += ".\n"

        lines = [header]
        for idx, trip in enumerate(trips, start=1):
            lines.append(
                f"{idx}. Mã chuyến #{trip['trip_id']} | {trip['time_text']} | {trip['bus_type_text']} | "
                f"Còn {trip['available_seats']} ghế | {trip['price_text']}"
            )
        lines.append("\nAnh/chị có thể trả lời số thứ tự (ví dụ: 1), hoặc nói 'chuyến đầu', 'chuyến cuối', 'rẻ nhất'.")
        return "\n".join(lines)

    def format_no_trip_response(self, state, alternatives=None):
        response = (
            f"Dạ hiện em chưa thấy chuyến phù hợp cho tuyến {state.get('from') or 'điểm đi'} → "
            f"{state.get('to') or 'điểm đến'} vào {state.get('date_label') or state.get('date_iso') or 'ngày đã chọn'}."
        )
        if state.get("time_pref"):
            response += f" Em đã ưu tiên khung giờ {state['time_pref']['label']} nhưng chưa có chuyến phù hợp."
        if alternatives:
            response += "\nCác ngày gần nhất có chuyến: " + ", ".join(alternatives[:4]) + "."
        response += "\nAnh/chị có thể đổi ngày, đổi giờ hoặc nhập lại tuyến khác để em tìm tiếp ạ."
        return response

    def selection_error(self, total_options):
        return f"Dạ em chỉ thấy {total_options} lựa chọn thôi ạ. Anh/chị chọn số từ 1 đến {total_options} giúp em nhé."

    def greeting_message(self):
        return (
            f"Dạ em là trợ lý đặt vé của {self.persona['brand']}. "
            "Anh/chị có thể nhắn rất ngắn như: 'sg dl mai 2v', 'tphcm đi ha noi', 'hn hcm t6 toi' hoặc 'chuyến đầu'."
        )

    def default_message(self):
        return (
            "Dạ em có thể hỗ trợ tìm chuyến và dẫn mình sang trang chọn ghế. "
            "Anh/chị chỉ cần nhập nơi đi, nơi đến, ngày đi và số vé, ví dụ: 'sg dl mai 2v' hoặc '2 vé từ TP.HCM đi Hà Nội tối mai'."
        )

    def my_tickets_message(self, logged_in):
        if logged_in:
            return "Dạ anh/chị có thể xem vé tại [Vé của tôi](/my-tickets) ạ."
        return "Dạ để xem vé, anh/chị đăng nhập rồi vào mục [Vé của tôi](/my-tickets) giúp em nhé."

    def format_booking_redirect(self, trip):
        return (
            f"Dạ em mở chuyến #{trip['trip_id']} cho mình rồi ạ: {trip['route_text']} lúc {trip['time_text']}. "
            "Em đang chuyển sang trang chọn ghế."
        )

    def get_admin_insights(self, company_data):
        revenue = company_data.get("total_revenue", 0)
        occ = company_data.get("occupancy_rate", 0)
        total_trips = company_data.get("total_trips", 0)
        best_route = None
        if company_data.get("route_performance"):
            best_route = max(company_data["route_performance"], key=lambda item: item.get("revenue") or 0)

        parts = [
            f"Doanh thu hiện tại đạt {revenue:,.0f}đ.",
            f"Tỷ lệ lấp đầy trung bình khoảng {occ:.1f}% trên {total_trips} chuyến."
        ]
        if best_route:
            parts.append(
                f"Tuyến nổi bật nhất là {best_route['route']} với {best_route['bookings']} vé và doanh thu {best_route['revenue'] or 0:,.0f}đ."
            )
        parts.append("Gợi ý: ưu tiên tăng chuyến cho tuyến bán tốt và rà các chuyến có tỷ lệ lấp đầy thấp để tối ưu giờ chạy.")
        return " ".join(parts)

    def get_smart_suggestions(self, available_trips, user_history=None):
        suggestions = []
        preferred_routes = set(user_history or [])
        sorted_trips = sorted(
            available_trips or [],
            key=lambda trip: (
                0 if trip.get("route") in preferred_routes else 1,
                trip.get("time") or "",
                trip.get("price") or 0,
            )
        )
        for trip in sorted_trips[:3]:
            reason = "Khởi hành sớm, dễ chọn ghế."
            if trip.get("route") in preferred_routes:
                reason = "Phù hợp lịch sử tuyến anh/chị đã đặt."
            elif trip.get("type"):
                reason = f"Xe {self.human_bus_type(trip['type'])}, giờ đi thuận tiện."
            suggestions.append({"trip_id": trip["id"], "reason": reason})
        return suggestions


ai_service = AIService()
