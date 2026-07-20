/**
 * Grindpoint — Shared UI Utilities
 * Toast notifications, loading states, field error helpers
 */

// ─── Toast Notifications ────────────────────────────────────────────────────

let _toastContainer = null;

function getToastContainer() {
  if (_toastContainer) return _toastContainer;
  _toastContainer = document.createElement("div");
  _toastContainer.id = "gp-toast-container";
  _toastContainer.setAttribute("aria-live", "polite");
  document.body.appendChild(_toastContainer);
  return _toastContainer;
}

/**
 * Shows a toast notification.
 * @param {string} message
 * @param {"success"|"error"|"info"|"warning"} type
 * @param {number} duration ms
 */
function showToast(message, type = "info", duration = 4000) {
  const container = getToastContainer();

  const toast = document.createElement("div");
  toast.className = `gp-toast gp-toast--${type}`;

  const icons = {
    success: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>`,
    error: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`,
    warning: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>`,
    info: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>`,
  };

  toast.innerHTML = `
    <span class="gp-toast__icon">${icons[type] || icons.info}</span>
    <span class="gp-toast__message">${message}</span>
    <button class="gp-toast__close" aria-label="Dismiss">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
    </button>
  `;

  const close = toast.querySelector(".gp-toast__close");
  close.addEventListener("click", () => dismissToast(toast));

  container.appendChild(toast);

  requestAnimationFrame(() => {
    requestAnimationFrame(() => toast.classList.add("gp-toast--visible"));
  });

  const timer = setTimeout(() => dismissToast(toast), duration);
  toast._timer = timer;

  return toast;
}

function dismissToast(toast) {
  clearTimeout(toast._timer);
  toast.classList.remove("gp-toast--visible");
  toast.classList.add("gp-toast--hiding");
  toast.addEventListener("transitionend", () => toast.remove(), { once: true });
}

// ─── Button Loading State ────────────────────────────────────────────────────

/**
 * Sets a button into loading state.
 * @param {HTMLButtonElement} btn
 * @param {string} loadingText
 */
function setButtonLoading(btn, loadingText = "Please wait…") {
  if (!btn) return;
  btn.disabled = true;
  btn._originalHTML = btn.innerHTML;
  btn.innerHTML = `<span class="btn-spinner"></span><span>${loadingText}</span>`;
  btn.classList.add("btn--loading");
}

/**
 * Restores a button from loading state.
 * @param {HTMLButtonElement} btn
 */
function clearButtonLoading(btn) {
  if (!btn) return;
  btn.disabled = false;
  btn.innerHTML = btn._originalHTML || btn.innerHTML;
  btn.classList.remove("btn--loading");
}

// ─── Field Error Helpers ─────────────────────────────────────────────────────

/**
 * Shows a validation error below a field.
 * @param {string} fieldId
 * @param {string} message
 */
function showFieldError(fieldId, message) {
  const field = document.getElementById(fieldId);
  if (!field) return;

  clearFieldError(fieldId);

  field.classList.add("field--error");

  const err = document.createElement("span");
  err.className = "field-error-msg";
  err.id = `${fieldId}-error`;
  err.textContent = message;
  err.setAttribute("role", "alert");

  field.parentNode.insertBefore(err, field.nextSibling);
}

/**
 * Clears the validation error for a field.
 */
function clearFieldError(fieldId) {
  const field = document.getElementById(fieldId);
  if (field) field.classList.remove("field--error");

  const existing = document.getElementById(`${fieldId}-error`);
  if (existing) existing.remove();
}

/**
 * Clears all field errors in a form.
 */
function clearAllFieldErrors(formEl) {
  if (!formEl) return;
  formEl.querySelectorAll(".field--error").forEach(f => f.classList.remove("field--error"));
  formEl.querySelectorAll(".field-error-msg").forEach(e => e.remove());
}

// ─── Password Toggle ─────────────────────────────────────────────────────────

/**
 * Wires a show/hide toggle button to a password input.
 * @param {string} inputId
 * @param {string} toggleId
 */
function initPasswordToggle(inputId, toggleId) {
  const input = document.getElementById(inputId);
  const toggle = document.getElementById(toggleId);
  if (!input || !toggle) return;

  toggle.addEventListener("click", () => {
    const isPassword = input.type === "password";
    input.type = isPassword ? "text" : "password";
    toggle.setAttribute("aria-label", isPassword ? "Hide password" : "Show password");
    toggle.innerHTML = isPassword ? EYE_OFF_SVG : EYE_SVG;
  });
}

const EYE_SVG = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>`;
const EYE_OFF_SVG = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 11-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>`;

// ─── Nav Active State ────────────────────────────────────────────────────────

function setActiveNav() {
  const current = window.location.pathname.split("/").pop() || "index";
  document.querySelectorAll(".nav__link").forEach(link => {
    const href = link.getAttribute("href");
    if (href && href.includes(current)) {
      link.classList.add("nav__link--active");
    }
  });
}

// ─── Modal Helpers ───────────────────────────────────────────────────────────

function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (!modal) return;
  modal.classList.add("modal--open");
  document.body.style.overflow = "hidden";
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (!modal) return;
  modal.classList.remove("modal--open");
  document.body.style.overflow = "";
}

function initModalCloseOnBackdrop(modalId) {
  const modal = document.getElementById(modalId);
  if (!modal) return;
  modal.addEventListener("click", (e) => {
    if (e.target === modal) closeModal(modalId);
  });
}

// ─── Countdown Helper ────────────────────────────────────────────────────────

function startCountdown(seconds, callback) {
  let remaining = seconds;
  const interval = setInterval(() => {
    remaining--;
    if (remaining <= 0) {
      clearInterval(interval);
      if (callback) callback();
    }
  }, 1000);
  return interval;
}

// ─── Init on DOM Ready ───────────────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  setActiveNav();
});
