(function () {
    const CHAT_SELECTORS = '#bt-chat-window, #bt-chatbot-toggle, #bt-chatbot-close, #bt-chatbot-maximize, #bt-chat-send, #bt-chat-input';
    const ACTION_SELECTOR = [
        'a[href]',
        'button',
        'input:not([type="hidden"])',
        'select',
        'textarea',
        '[role="button"]',
        '.bt-bus-seat'
    ].join(',');

    function normalizeText(value) {
        return String(value || '')
            .trim()
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/đ/g, 'd')
            .replace(/[^a-z0-9@._:/\-\s]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function isVisible(el) {
        if (!el || el.disabled || el.getAttribute('aria-disabled') === 'true') return false;
        if (el.closest(CHAT_SELECTORS)) return false;
        const style = window.getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) return false;
        const rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
    }

    function cleanLabel(value) {
        return String(value || '')
            .replace(/\s+/g, ' ')
            .replace(/[\n\t]+/g, ' ')
            .trim()
            .slice(0, 160);
    }

    function getLabelFromForm(el) {
        const form = el.closest('form');
        if (!form) return '';
        const heading = form.querySelector('h1,h2,h3,h4,.card-title,.section-title,.booking-aside-title,.auth-title');
        if (heading) return cleanLabel(heading.textContent);
        return '';
    }

    function cssEscape(value) {
        if (window.CSS && typeof window.CSS.escape === 'function') return window.CSS.escape(value);
        return String(value || '').replace(/[^a-zA-Z0-9_-]/g, '\\$&');
    }

    function getFieldLabel(el) {
        if (!el) return '';
        const labels = [];

        if (el.id) {
            const directLabel = document.querySelector(`label[for="${cssEscape(el.id)}"]`);
            if (directLabel) labels.push(directLabel.textContent);
        }

        const wrappingLabel = el.closest('label');
        if (wrappingLabel) labels.push(wrappingLabel.textContent);

        const group = el.closest('.form-group, .input-group, .auth-field, .booking-field, .profile-field, .field, .bt-form-group');
        if (group) {
            const groupLabel = group.querySelector('label, .form-label, .field-label');
            if (groupLabel) labels.push(groupLabel.textContent);
        }

        labels.push(el.getAttribute('aria-label'));
        labels.push(el.placeholder);
        labels.push(el.name);
        labels.push(el.id);
        return cleanLabel(labels.filter(Boolean).join(' '));
    }

    function ensureSelector(el) {
        if (!el.dataset.aiActionId) {
            el.dataset.aiActionId = `ai-action-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
        }
        return `[data-ai-action-id="${el.dataset.aiActionId}"]`;
    }

    function getActionKind(el) {
        const tag = el.tagName.toLowerCase();
        const type = (el.getAttribute('type') || '').toLowerCase();
        if (el.classList.contains('bt-bus-seat')) return 'seat';
        if (tag === 'a') return 'navigate';
        if (tag === 'select' || tag === 'textarea' || tag === 'input' && !['button', 'submit', 'reset'].includes(type)) return 'field';
        if (tag === 'button' && (type === 'submit' || !type && el.closest('form'))) return 'submit';
        if (tag === 'input' && ['button', 'submit', 'reset'].includes(type)) return type === 'submit' ? 'submit' : 'click';
        return 'click';
    }

    function collectPageActions() {
        const actions = [];
        const elements = Array.from(document.querySelectorAll(ACTION_SELECTOR));

        elements.forEach((el) => {
            if (!isVisible(el)) return;
            const tag = el.tagName.toLowerCase();
            const kind = getActionKind(el);
            let label = '';

            if (kind === 'field') {
                label = getFieldLabel(el);
            } else if (kind === 'seat') {
                const sid = el.dataset.sid || cleanLabel(el.textContent);
                label = `Chọn ghế ${sid}`;
            } else {
                label = cleanLabel([
                    el.innerText,
                    el.value,
                    el.getAttribute('aria-label'),
                    el.getAttribute('title'),
                    el.name,
                    el.id
                ].filter(Boolean).join(' '));
            }

            if (!label && el.href) label = el.href;
            if (!label) return;

            const rect = el.getBoundingClientRect();
            const options = tag === 'select'
                ? Array.from(el.options || []).map(opt => ({ text: cleanLabel(opt.textContent), value: opt.value })).slice(0, 80)
                : [];

            actions.push({
                selector: ensureSelector(el),
                label,
                label_normalized: normalizeText(label),
                kind,
                tag,
                type: (el.getAttribute('type') || '').toLowerCase(),
                href: el.href || el.getAttribute('href') || '',
                id: el.id || '',
                name: el.name || '',
                title: el.getAttribute('title') || '',
                aria: el.getAttribute('aria-label') || '',
                placeholder: el.getAttribute('placeholder') || '',
                form_label: getLabelFromForm(el),
                value: kind === 'field' ? el.value || '' : '',
                options,
                top: Math.round(rect.top + window.scrollY),
                left: Math.round(rect.left + window.scrollX)
            });
        });

        return actions.slice(0, 160);
    }

    function flashElement(el) {
        if (!el) return;
        const oldOutline = el.style.outline;
        const oldBoxShadow = el.style.boxShadow;
        const oldTransition = el.style.transition;
        el.style.transition = 'box-shadow .2s ease, outline .2s ease';
        el.style.outline = '3px solid #f59e0b';
        el.style.boxShadow = '0 0 0 6px rgba(245, 158, 11, .22)';
        setTimeout(() => {
            el.style.outline = oldOutline;
            el.style.boxShadow = oldBoxShadow;
            el.style.transition = oldTransition;
        }, 1000);
    }

    function findOption(select, value) {
        const target = normalizeText(value);
        if (!target) return null;
        return Array.from(select.options || []).find(opt => {
            const text = normalizeText(opt.textContent);
            const optValue = normalizeText(opt.value);
            return text === target || optValue === target || text.includes(target) || target.includes(text);
        });
    }

    function fillField(el, value) {
        const tag = el.tagName.toLowerCase();
        const type = (el.getAttribute('type') || '').toLowerCase();
        if (tag === 'select') {
            const option = findOption(el, value);
            if (option) el.value = option.value;
        } else if (type === 'checkbox' || type === 'radio') {
            el.checked = ['true', '1', 'co', 'có', 'chon', 'chọn', 'yes', 'bat', 'bật'].includes(normalizeText(value));
        } else {
            el.value = value;
        }
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
        el.focus({ preventScroll: true });
    }

    function execute(action) {
        if (!action || !action.type) return false;

        if (action.type === 'open_booking' && action.trip_id) {
            window.location.href = `/book/${action.trip_id}`;
            return true;
        }

        if (action.type === 'navigate' && action.url) {
            window.location.href = action.url;
            return true;
        }

        const el = action.selector ? document.querySelector(action.selector) : null;

        if (action.type === 'scroll') {
            if (el) {
                flashElement(el);
                el.scrollIntoView({ behavior: 'smooth', block: 'center' });
            } else if (action.url) {
                window.location.href = action.url;
            }
            return true;
        }

        if (!el) return false;

        if (action.type === 'fill') {
            fillField(el, action.value || '');
            flashElement(el);
            return true;
        }

        if (action.type === 'click') {
            flashElement(el);
            el.scrollIntoView({ behavior: 'smooth', block: 'center' });
            setTimeout(() => el.click(), 260);
            return true;
        }

        if (action.type === 'submit_form') {
            const form = el.closest('form') || document.querySelector('form');
            if (form) {
                flashElement(form);
                if (form.requestSubmit) form.requestSubmit();
                else form.submit();
                return true;
            }
        }

        return false;
    }

    window.AIPageActions = {
        collect: collectPageActions,
        execute,
        normalizeText
    };
})();
