// ==UserScript==
// @name         Zendesk → mg_att2link Auto Downloader (iframe-safe, SPA-safe)
// @namespace    tm.zendesk.mg-auto-download
// @version      2.0.0
// @description  Finds mg_att2link links in Zendesk tickets, opens auth in a top-level tab, auto-fills password, clicks download, and copies "ticketId filename" to clipboard.
// @match        https://cmtelematics.zendesk.com/agent/tickets/*
// @match        https://mgf-filelink.cybermail.jp/*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_addStyle
// @grant        GM_openInTab
// @grant        GM_registerMenuCommand
// @grant        GM_setClipboard
// @grant        GM_xmlhttpRequest
// @connect      mgf-filelink.cybermail.jp
// ==/UserScript==

/* ----------------------------- Styles ----------------------------- */
GM_addStyle(`
  #mg-auto-btn{
    position: fixed; left: 16px; top: 16px;            /* draggable; persisted via GM storage */
    z-index: 2147483647 !important;
    padding: 12px 18px; border: 0; border-radius: 10px;
    background:#0b5fff; color:#fff; font:600 14px/1.2 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
    box-shadow:0 10px 24px rgba(0,0,0,.25);
    user-select:none; touch-action:none;               /* better dragging on touch/trackpads */
  }
  #mg-auto-btn.hidden{ display:none !important; }
  #mg-auto-btn .label{}         /* so dragging anywhere works */
  #mg-auto-btn .close{
    margin-left:10px; background:transparent; border:0; color:#fff; opacity:.85; font-weight:800;
    cursor:pointer; padding:0 2px; line-height:1; font-size:16px;
  }
  #mg-auto-btn .close:hover{ opacity:1; }
  #mg-auto-btn.dragging{ cursor:grabbing; }
  #mg-auto-btn{ cursor:grab; }
`);

/* ----------------------------- Script ----------------------------- */
(function () {
  'use strict';

  /* ====== Config (edit these) ====== */
  const MG_ORIGIN = 'https://mgf-filelink.cybermail.jp'

  /* ====== Constants & Utils ====== */
  const LINK_SELECTOR = 'a[href*="/mg-cgi/mg_att2link_auth"]';
  const isZendesk = location.hostname.endsWith('.zendesk.com') || document.referrer.includes('.zendesk.com');
  const isAuthPage = /\/mg-cgi\/mg_att2link_auth/i.test(location.pathname);
  const isAttachListPage = /\/mg-cgi\/mg_att2link_attach_list/i.test(location.pathname);
  const isMGRoot = location.origin === MG_ORIGIN && location.pathname === '/';

  const HIDDEN_KEY = `mg_btn_hidden@${location.hostname}`;
  const POS_KEY    = `mg_btn_pos@${location.hostname}`;

  const sleep = (ms) => new Promise(r => setTimeout(r, ms));
  const log = (...args) => console.log('[mg-auto]', ...args);

  const getHidden = () => !!GM_getValue(HIDDEN_KEY, false);
  const setHidden = (v) => GM_setValue(HIDDEN_KEY, !!v);

  function getTicketIdFromUrl(u) {
    try {
      const m = new URL(u, location.href).pathname.match(/\/agent\/tickets\/(\d+)/);
      return m ? m[1] : '';
    } catch { return ''; }
  }

  function isVisible(el) {
    return !!(el && el.offsetParent !== null && getComputedStyle(el).visibility !== 'hidden');
  }

  function getCurrentAuthLinks(root = document) {
    return Array.from(root.querySelectorAll(LINK_SELECTOR))
      .filter(isVisible)
      .map(a => new URL(a.href, location.href).toString());
  }

  function inferFilenameFromUrl(u) {
    try {
      const last = new URL(u, location.href).pathname.split('/').pop() || 'download.bin';
      return decodeURIComponent(last);
    } catch { return 'download.bin'; }
  }

  // HEAD request for Content-Disposition filename; falls back to URL
  function getServerFilename(url) {
    return new Promise((resolve) => {
      GM_xmlhttpRequest({
        method: 'HEAD',
        url,
        onload: (res) => {
          const hdrs = res.responseHeaders || '';
          const m1 = /filename\*=(?:UTF-8''|)([^;\r\n]+)/i.exec(hdrs);
          const m2 = /filename="?([^";\r\n]+)"?/i.exec(hdrs);
          const raw = (m1 && m1[1]) || (m2 && m2[1]);
          if (raw) {
            try { resolve(decodeURIComponent(raw)); } catch { resolve(raw); }
          } else {
            resolve(inferFilenameFromUrl(url));
          }
        },
        onerror:  () => resolve(inferFilenameFromUrl(url)),
        ontimeout:() => resolve(inferFilenameFromUrl(url)),
        timeout: 8000,
      });
    });
  }

  async function copyTicketAndFilenameToClipboard(downloadUrl) {
    const ticket = (GM_getValue('mg_ticket_id', '') + '').trim();
    const fname  = await getServerFilename(downloadUrl);
    const text   = ticket ? `${ticket} ${fname}` : fname;
    GM_setClipboard(text, { type: 'text', mimetype: 'text/plain' });
    log('Copied to clipboard:', text);
  }

  /* ====== Draggable (with click suppression) ====== */
  function makeButtonDraggable(btn) {
    const saved = GM_getValue(POS_KEY, null);
    if (saved && typeof saved.left === 'number' && typeof saved.top === 'number') {
      btn.style.left = `${saved.left}px`;
      btn.style.top  = `${saved.top}px`;
      btn.style.right = 'auto';
      btn.style.bottom= 'auto';
      btn.style.transform = 'none';
    }

    let startX=0, startY=0, startLeft=0, startTop=0, rect=null;
    let moved = false;
    const THRESHOLD = 6;        // pixels before we treat as drag
    let suppressClickUntil = 0; // timestamp to ignore clicks after drag

    const onPointerDown = (e) => {
      btn.classList.add('dragging');
      btn.setPointerCapture(e.pointerId);

      rect = btn.getBoundingClientRect();
      startX = e.clientX;
      startY = e.clientY;
      startLeft = rect.left;
      startTop  = rect.top;
      moved = false;

      // Ensure using left/top
      btn.style.left = `${rect.left}px`;
      btn.style.top  = `${rect.top}px`;
      btn.style.right = 'auto';
      btn.style.bottom= 'auto';
      btn.style.transform = 'none';

      window.addEventListener('pointermove', onPointerMove);
      window.addEventListener('pointerup', onPointerUp, { once: true });
      e.preventDefault();
    };

    const onPointerMove = (e) => {
      const dx = e.clientX - startX;
      const dy = e.clientY - startY;

      if (!moved && (Math.abs(dx) > THRESHOLD || Math.abs(dy) > THRESHOLD)) {
        moved = true;
      }

      // clamp inside viewport
      const w = rect.width, h = rect.height;
      const maxX = Math.max(0, window.innerWidth  - w);
      const maxY = Math.max(0, window.innerHeight - h);

      let x = Math.min(maxX, Math.max(0, startLeft + dx));
      let y = Math.min(maxY, Math.max(0, startTop  + dy));

      btn.style.left = `${x}px`;
      btn.style.top  = `${y}px`;
    };

    const onPointerUp = (e) => {
      btn.classList.remove('dragging');
      try { btn.releasePointerCapture(e.pointerId); } catch {}

      window.removeEventListener('pointermove', onPointerMove);

      // Persist position
      const left = parseFloat(btn.style.left) || 0;
      const top  = parseFloat(btn.style.top)  || 0;
      GM_setValue(POS_KEY, { left, top });

      // If we dragged, suppress the click that follows pointerup
      if (moved) {
        suppressClickUntil = Date.now() + 300;
      }
    };

    // Capture-phase click filter to prevent click-after-drag
    btn.addEventListener('click', (e) => {
      if (Date.now() < suppressClickUntil) {
        e.stopPropagation();
        e.preventDefault();
      }
    }, true);

    btn.addEventListener('pointerdown', onPointerDown);
  }

  /* ====== Button injection + visibility ====== */
  function ensureButtonLabel(btn, text) {
    let label = btn.querySelector('.label');
    if (!label) {
      btn.innerHTML = `<span class="label"></span> <span class="close" title="Hide" aria-label="Hide" role="button">×</span>`;
      label = btn.querySelector('.label');
    }
    label.textContent = text;
  }

  function injectButtonIfNeeded(count = 0) {
    let btn = document.getElementById('mg-auto-btn');
    if (!btn) {
      // Use a DIV as the container to allow an inner close element without nested button quirks
      btn = document.createElement('div');
      btn.id = 'mg-auto-btn';
      btn.setAttribute('role', 'button');
      btn.setAttribute('tabindex', '0');
      btn.innerHTML = `<span class="label"></span> <span class="close" title="Hide" aria-label="Hide" role="button">×</span>`;
      (document.body || document.documentElement).appendChild(btn);

      // Open flow (only if not clicking on the close element)
      btn.addEventListener('click', (ev) => {
          let inClose = false;
          if (typeof ev.composedPath === 'function') {
          inClose = ev.composedPath().some(n => n instanceof Element && n.classList.contains('close'));
          } else {
          const t = ev.target;
          inClose = t && t.nodeType === 1 && t.closest && t.closest('.close');
          }
        ev.preventDefault();
        ev.stopPropagation();
        onAutoDownloadClick();
      }, { passive: false });

      // Keyboard activation (Enter/Space)
      btn.addEventListener('keydown', (e) => {
        if ((e.key === 'Enter' || e.key === ' ') && !e.repeat) {
          e.preventDefault();
          onAutoDownloadClick();
        }
      });

      // Close/hide
     const closeBtn = btn.querySelector('.close');
     if (closeBtn) {
     // Prevent drag start and any parent handlers
       closeBtn.addEventListener('pointerdown', (e) => {
         e.preventDefault();
         e.stopPropagation();
        }, true);

       closeBtn.addEventListener('click', async (e) => {
         e.preventDefault();
         e.stopImmediatePropagation();   // ensures no other click handlers fire
         btn.classList.add('hidden');
         await setHidden(true);          // your per-host visibility setter
       });
    }

      // Draggable
      makeButtonDraggable(btn);
    }
    ensureButtonLabel(btn, count ? `Auto-download mg-attachments (${count})` : 'Auto-download');
    btn.classList.toggle('hidden', getHidden());
  }

  function updateButtonVisibility() {
    const links = getCurrentAuthLinks();
    if (links.length === 0) {
      const btn = document.getElementById('mg-auto-btn');
      if (btn) btn.classList.add('hidden');
      return;
    }
    injectButtonIfNeeded(links.length);
  }

  // Debounced rescans for SPA/DOM changes
  let rescanTimer = null;
  function scheduleRescan() {
    clearTimeout(rescanTimer);
    rescanTimer = setTimeout(updateButtonVisibility, 120);
  }

  /* ====== SPA navigation hooks ====== */
  (function hookHistory() {
    const fire = (name) => () => window.dispatchEvent(new CustomEvent('tm:navigate', { detail: name }));
    const _push = history.pushState;
    history.pushState = function () { const r = _push.apply(this, arguments); fire('pushState')(); return r; };
    const _replace = history.replaceState;
    history.replaceState = function () { const r = _replace.apply(this, arguments); fire('replaceState')(); return r; };
    window.addEventListener('popstate', fire('popstate'));
    window.addEventListener('pageshow', (e) => { if (e.persisted) fire('pageshow-bfcache')(); });
  })();

  window.addEventListener('tm:navigate', () => {
    // Clear any per-ticket transient state if needed
    GM_setValue('mg_last_auth', '');
    scheduleRescan();
  });

  // Observe the main ticket container; fallback to body
  const container = document.querySelector('#main_pane, #app_container, [data-test-id="main-pane"]') || document.body;
  new MutationObserver(scheduleRescan).observe(container, { childList: true, subtree: true });

  // Menu + hotkey to toggle visibility (per-host)
  GM_registerMenuCommand('Toggle Button (Ctrl+B)', () => {
    const now = !getHidden();
    setHidden(now);
    const btn = document.getElementById('mg-auto-btn');
    if (btn) btn.classList.toggle('hidden', now);
  });

  if (!window.__mgHotkeyBound) {
    window.__mgHotkeyBound = true;
    window.addEventListener('keydown', (e) => {
      if (e.ctrlKey && !e.altKey && !e.metaKey && !e.shiftKey && String(e.key).toLowerCase() === 'b') {
        e.preventDefault();
        const now = !getHidden();
        setHidden(now);
        const btn = document.getElementById('mg-auto-btn');
        if (btn) btn.classList.toggle('hidden', now);
      }
    }, { capture: true });
  }

    // Menu item for discoverability (optional)
    GM_registerMenuCommand('Run Auto-download (Ctrl+D)', () => safeHotkeyTrigger());
    
    // ---- Global hotkey to run the flow ----
    if (!window.__mgRunHotkeyBound) {
      window.__mgRunHotkeyBound = true;
    
      const isTypingTarget = (el) => {
        if (!el) return false;
        if (el.isContentEditable) return true;
        const tag = (el.tagName || '').toUpperCase();
        return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
      };
    
      let lastTs = 0; // throttle to avoid repeats
    
      window.addEventListener('keydown', (e) => {
        // Don’t trigger while user is typing in a field
        if (isTypingTarget(document.activeElement)) return;
    
        // Hotkeys:
        //  - Ctrl + D  (simple)
        //  - Ctrl/Cmd + Shift + D  (alternative, esp. on macOS)
        const key = String(e.key || '').toLowerCase();
        const ctrlD   = e.ctrlKey && !e.altKey && !e.metaKey && !e.shiftKey && key === 'd';
    
        if (ctrlD && !e.repeat) {
          const now = Date.now();
          if (now - lastTs < 500) return; // 0.5s throttle
          lastTs = now;
    
          e.preventDefault();
          e.stopPropagation();
          safeHotkeyTrigger();
        }
      }, true);
    }
    
    // Fire the right step depending on where we are
    function safeHotkeyTrigger() {
      try {
        if (isZendesk) {
          onAutoDownloadClick();     // same as pressing the floating button
        } else if (isAuthPage) {
          runOnAuthPage();           // fill password & submit
        } else if (isAttachListPage) {
          runOnAttachListPage();     // copy "ticket filename" & download
        } else {
          console.log('[mg-auto] Hotkey pressed, but this page has no action.');
        }
      } catch (err) {
        console.error('[mg-auto] Hotkey error:', err);
      }
    }
  /* ====== Core flow ====== */

  // Invoked from button click: always compute fresh links from current ticket DOM
  async function onAutoDownloadClick() {
    // 1) Read password from clipboard; prompt fallback
    let pw = '';
    try { pw = (await navigator.clipboard.readText()).trim(); } catch {}
    if (!pw) pw = (window.prompt('Paste the password (clipboard blocked):', '') || '').trim();
    if (!pw) return;

    GM_setValue('mg_pw', pw);
    GM_setValue('mg_flow_ts', Date.now());

    // 2) Save current ticket id (for clipboard later on mg host)
    const tid = getTicketIdFromUrl(location.href);
    GM_setValue('mg_ticket_id', tid);

    // 3) Freshly collect links from this Zendesk page/frame
    const links = getCurrentAuthLinks();
    if (!links.length) { alert('No mg_att2link_auth links found on this ticket.'); return; }
    const authUrl = links[0];
    GM_setValue('mg_last_auth', authUrl);

    // 4) Optionally hide the button to avoid stale clicks mid-navigation
    const btn = document.getElementById('mg-auto-btn');
    if (btn) btn.classList.add('hidden');
    setHidden(true); // remember per-host

    // 5) Open auth in a NEW TAB (top-level context)
    GM_openInTab(authUrl, { active: true, insert: true, setParent: true });
  }

  // Auto-fill password on the mg auth page and submit
  async function runOnAuthPage() {
    const pw = (GM_getValue('mg_pw', '') + '').trim();
    if (!pw) return;

    for (let i = 0; i < 120; i++) {
      const inp =
        document.querySelector('input[type="password"]') ||
        document.querySelector('input[name*="pass" i]') ||
        document.querySelector('input[name*="pwd" i]');
      if (inp) {
        inp.focus();
        inp.value = pw;
        const form = inp.closest('form') || document.querySelector('form[action*="mg_att2link_attach_list"], form');
        if (form) {
          if (typeof form.requestSubmit === 'function') form.requestSubmit();
          else form.submit();
        } else {
          console.warn('[mg-auto] No form to submit from auth page.');
        }
        return;
      }
      await sleep(100);
    }
    console.warn('[mg-auto] Password field not found on auth page.');
  }

  // On the mg attach list: find download link, copy "ticket filename", and trigger download
  async function runOnAttachListPage() {
    await sleep(200);
    let links = findDownloadLinks();
    for (let i = 0; i < 20 && !links.length; i++) { await sleep(150); links = findDownloadLinks(); }
    if (!links.length) { console.warn('[mg-auto] No download links found on attach list.'); return; }

    // Copy "ticket filename" to clipboard
    await copyTicketAndFilenameToClipboard(links[0]);

    // Trigger the first downloadn
    location.assign(links[0]);

    // Clear password shortly after
    setTimeout(() => GM_setValue('mg_pw', ''), 3000);
  }

  function findDownloadLinks() {
    const anchors = Array.from(document.querySelectorAll('a[href]'));
    const dl = anchors
      .map(a => a.getAttribute('href'))
      .filter(h => h && /\/mg-cgi\/att2link_download\/.*\?k=/i.test(h))
      .map(h => new URL(h, location.href).toString());
    return Array.from(new Set(dl));
  }

  // Some mg deployments bounce framed loads to "/" first; jump back to the saved auth URL
  function runOnMGRootBounce() {
    const ts = GM_getValue('mg_flow_ts', 0);
    const last = GM_getValue('mg_last_auth', '');
    if (last && Date.now() - ts < 120000) {
      location.replace(last);
    }
  }

  /* ====== Boot ====== */
  (async function main() {
    try {
      if (isZendesk) {
        updateButtonVisibility();    // initial
        return;                      // observers keep it fresh
      }
      if (isAuthPage) return runOnAuthPage();
      if (isAttachListPage) return runOnAttachListPage();
      if (isMGRoot) return runOnMGRootBounce();
    } catch (e) {
      console.error('[mg-auto] Error:', e);
    }
  })();

})();
