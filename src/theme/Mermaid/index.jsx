import React, {useCallback, useEffect, useRef, useState} from 'react';
import {createPortal} from 'react-dom';
import MermaidOriginal from '@theme-original/Mermaid';
import styles from './styles.module.css';

const MIN_SCALE = 0.25;
const MAX_SCALE = 10;
const ZOOM_STEP = 1.25;
// Diagrams open scaled to fit the viewport, but no larger than this — small
// diagrams don't need to be blown up to fill a large screen.
const MAX_FIT_SCALE = 4;
const FIT_MARGIN = 0.9;

const INITIAL_VIEW = {scale: 1, x: 0, y: 0};

function clampScale(scale) {
  return Math.min(MAX_SCALE, Math.max(MIN_SCALE, scale));
}

// Scale the view by `factor`, keeping `origin` (viewport coordinates relative
// to the viewport center, the transform origin) fixed on screen.
function zoomView(view, factor, origin = {x: 0, y: 0}) {
  const scale = clampScale(view.scale * factor);
  const ratio = scale / view.scale;
  return {
    scale,
    x: origin.x - ratio * (origin.x - view.x),
    y: origin.y - ratio * (origin.y - view.y),
  };
}

function ExpandIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
      <path
        d="M9.5 1.5h5v5m0-5L9 7M6.5 14.5h-5v-5m0 5L7 9"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function DiagramLightbox({onClose, ...mermaidProps}) {
  const [view, setView] = useState(INITIAL_VIEW);
  const dialogRef = useRef(null);
  const viewportRef = useRef(null);
  const contentRef = useRef(null);
  const dragState = useRef(null);
  const fitScale = useRef(1);
  const interacted = useRef(false);

  const zoomBy = useCallback((factor, origin) => {
    interacted.current = true;
    setView((current) => zoomView(current, factor, origin));
  }, []);

  const resetView = useCallback(() => {
    setView({scale: fitScale.current, x: 0, y: 0});
  }, []);

  // Mermaid renders its SVG asynchronously and at its natural (often small)
  // size — once it has a size, scale the diagram up to fit the viewport so it
  // opens readable instead of tiny. Skipped once the user zoomed or panned.
  useEffect(() => {
    const viewport = viewportRef.current;
    const content = contentRef.current;
    if (!viewport || !content || typeof ResizeObserver === 'undefined') {
      return undefined;
    }
    const observer = new ResizeObserver(() => {
      const contentWidth = content.offsetWidth;
      const contentHeight = content.offsetHeight;
      const viewportRect = viewport.getBoundingClientRect();
      if (!contentWidth || !contentHeight || !viewportRect.width || !viewportRect.height) {
        return;
      }
      const fit = clampScale(
        Math.min(
          (viewportRect.width / contentWidth) * FIT_MARGIN,
          (viewportRect.height / contentHeight) * FIT_MARGIN,
          MAX_FIT_SCALE,
        ),
      );
      fitScale.current = fit;
      if (!interacted.current) {
        setView({scale: fit, x: 0, y: 0});
      }
      observer.disconnect();
    });
    observer.observe(content);
    return () => observer.disconnect();
  }, []);

  // Close on Escape and lock page scrolling while the lightbox is open.
  useEffect(() => {
    dialogRef.current?.focus();
    const onKeyDown = (event) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };
    document.addEventListener('keydown', onKeyDown);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [onClose]);

  // React registers wheel listeners as passive, so a native non-passive
  // listener is needed to preventDefault the page scroll while zooming.
  // Zoom is anchored at the cursor so the point under it stays fixed.
  useEffect(() => {
    const viewport = viewportRef.current;
    if (!viewport) {
      return undefined;
    }
    const onWheel = (event) => {
      event.preventDefault();
      const rect = viewport.getBoundingClientRect();
      const origin = {
        x: event.clientX - rect.left - rect.width / 2,
        y: event.clientY - rect.top - rect.height / 2,
      };
      zoomBy(event.deltaY < 0 ? ZOOM_STEP : 1 / ZOOM_STEP, origin);
    };
    viewport.addEventListener('wheel', onWheel, {passive: false});
    return () => viewport.removeEventListener('wheel', onWheel);
  }, [zoomBy]);

  const onDialogKeyDown = (event) => {
    if (event.key !== 'Tab') {
      return;
    }
    const focusables = dialogRef.current?.querySelectorAll('button');
    if (!focusables || focusables.length === 0) {
      return;
    }
    const first = focusables[0];
    const last = focusables[focusables.length - 1];
    const active = document.activeElement;
    // `active` may also be the dialog container itself (focused on open) —
    // keep focus inside the dialog in that case too.
    const activeIndex = Array.prototype.indexOf.call(focusables, active);
    if (event.shiftKey && (active === first || activeIndex === -1)) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && active === last) {
      event.preventDefault();
      first.focus();
    }
  };

  const onPointerDown = (event) => {
    // Single-pointer pan: ignore secondary buttons and additional touches.
    if (event.button !== 0 || dragState.current) {
      return;
    }
    interacted.current = true;
    event.currentTarget.setPointerCapture?.(event.pointerId);
    dragState.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      baseX: view.x,
      baseY: view.y,
    };
  };

  const onPointerMove = (event) => {
    const drag = dragState.current;
    if (!drag || event.pointerId !== drag.pointerId) {
      return;
    }
    setView((current) => ({
      ...current,
      x: drag.baseX + (event.clientX - drag.startX),
      y: drag.baseY + (event.clientY - drag.startY),
    }));
  };

  const onPointerUp = (event) => {
    if (dragState.current && event.pointerId === dragState.current.pointerId) {
      dragState.current = null;
    }
  };

  const onBackdropClick = (event) => {
    if (event.target === event.currentTarget) {
      onClose();
    }
  };

  return createPortal(
    <div className={styles.backdrop} onClick={onBackdropClick}>
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-label="Fullscreen diagram"
        tabIndex={-1}
        className={styles.dialog}
        onKeyDown={onDialogKeyDown}>
        <div className={styles.toolbar}>
          <button
            type="button"
            className={styles.toolbarButton}
            aria-label="Zoom out"
            title="Zoom out"
            onClick={() => zoomBy(1 / ZOOM_STEP)}>
            −
          </button>
          <button
            type="button"
            className={styles.toolbarButton}
            aria-label="Reset zoom"
            title="Reset zoom"
            onClick={resetView}>
            {Math.round(view.scale * 100)}%
          </button>
          <button
            type="button"
            className={styles.toolbarButton}
            aria-label="Zoom in"
            title="Zoom in"
            onClick={() => zoomBy(ZOOM_STEP)}>
            +
          </button>
          <button
            type="button"
            className={styles.toolbarButton}
            aria-label="Close fullscreen diagram"
            title="Close (Esc)"
            onClick={onClose}>
            ×
          </button>
        </div>
        <div
          ref={viewportRef}
          className={styles.viewport}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}>
          <div
            className={styles.canvas}
            data-testid="diagram-canvas"
            style={{transform: `translate(${view.x}px, ${view.y}px) scale(${view.scale})`}}>
            <div ref={contentRef} data-testid="diagram-content">
              <MermaidOriginal {...mermaidProps} />
            </div>
          </div>
        </div>
      </div>
    </div>,
    document.body,
  );
}

export default function MermaidWrapper(props) {
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const expandButtonRef = useRef(null);

  const closeLightbox = useCallback(() => {
    setLightboxOpen(false);
    expandButtonRef.current?.focus();
  }, []);

  return (
    <div className={styles.container}>
      <MermaidOriginal {...props} />
      <button
        ref={expandButtonRef}
        type="button"
        className={styles.expandButton}
        aria-label="Open diagram in fullscreen"
        title="Open diagram in fullscreen"
        onClick={() => setLightboxOpen(true)}>
        <ExpandIcon />
      </button>
      {lightboxOpen && <DiagramLightbox {...props} onClose={closeLightbox} />}
    </div>
  );
}
