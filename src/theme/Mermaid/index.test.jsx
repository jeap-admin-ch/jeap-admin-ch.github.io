import {act, cleanup, fireEvent, render, screen, within} from '@testing-library/react';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import MermaidWrapper from './index';

const DIAGRAM = 'graph TD; A-->B;';

function renderDiagram() {
  return render(<MermaidWrapper value={DIAGRAM} />);
}

function openLightbox() {
  const utils = renderDiagram();
  fireEvent.click(screen.getByRole('button', {name: 'Open diagram in fullscreen'}));
  const dialog = screen.getByRole('dialog', {name: 'Fullscreen diagram'});
  const canvas = screen.getByTestId('diagram-canvas');
  return {...utils, dialog, canvas, viewport: canvas.parentElement};
}

afterEach(cleanup);

describe('MermaidWrapper', () => {
  it('renders the diagram with an expand button', () => {
    renderDiagram();
    expect(screen.getByTestId('mermaid-diagram')).toHaveTextContent(DIAGRAM);
    expect(
      screen.getByRole('button', {name: 'Open diagram in fullscreen'}),
    ).toBeInTheDocument();
  });

  it('does not render the lightbox initially', () => {
    renderDiagram();
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('opens the fullscreen lightbox with a second rendering of the diagram', () => {
    const {dialog} = openLightbox();
    expect(within(dialog).getByTestId('mermaid-diagram')).toHaveTextContent(DIAGRAM);
    expect(screen.getAllByTestId('mermaid-diagram')).toHaveLength(2);
  });

  it('locks page scrolling while open and unlocks it on close', () => {
    openLightbox();
    expect(document.body.style.overflow).toBe('hidden');
    fireEvent.click(screen.getByRole('button', {name: 'Close fullscreen diagram'}));
    expect(document.body.style.overflow).toBe('');
  });

  it('closes via the close button and returns focus to the expand button', () => {
    openLightbox();
    fireEvent.click(screen.getByRole('button', {name: 'Close fullscreen diagram'}));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.getByRole('button', {name: 'Open diagram in fullscreen'})).toHaveFocus();
  });

  it('closes on Escape', () => {
    openLightbox();
    fireEvent.keyDown(document, {key: 'Escape'});
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('closes when clicking the backdrop but not when clicking inside the dialog', () => {
    const {dialog} = openLightbox();
    fireEvent.click(dialog);
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    fireEvent.click(dialog.parentElement);
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  describe('zoom controls', () => {
    it('zooms in and out via the toolbar buttons', () => {
      const {dialog, canvas} = openLightbox();
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(1)');

      fireEvent.click(within(dialog).getByRole('button', {name: 'Zoom in'}));
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(1.25)');
      expect(within(dialog).getByRole('button', {name: 'Reset zoom'})).toHaveTextContent('125%');

      fireEvent.click(within(dialog).getByRole('button', {name: 'Zoom out'}));
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(1)');
      expect(within(dialog).getByRole('button', {name: 'Reset zoom'})).toHaveTextContent('100%');
    });

    it('clamps the zoom level to the minimum scale', () => {
      const {dialog} = openLightbox();
      const zoomOut = within(dialog).getByRole('button', {name: 'Zoom out'});
      for (let i = 0; i < 20; i += 1) {
        fireEvent.click(zoomOut);
      }
      expect(within(dialog).getByRole('button', {name: 'Reset zoom'})).toHaveTextContent('25%');
    });

    it('zooms with the mouse wheel', () => {
      const {canvas, viewport} = openLightbox();

      fireEvent.wheel(viewport, {deltaY: -100});
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(1.25)');

      fireEvent.wheel(viewport, {deltaY: 100});
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(1)');
    });

    it('anchors wheel zoom at the cursor position', () => {
      const {canvas, viewport} = openLightbox();

      // jsdom reports an all-zero bounding rect, so the viewport center is
      // (0, 0) and the cursor position is the zoom origin directly:
      // offset' = origin - ratio * origin = 100 - 1.25*100 = -25 (and -12.5).
      fireEvent.wheel(viewport, {deltaY: -100, clientX: 100, clientY: 50});
      expect(canvas.style.transform).toBe('translate(-25px, -12.5px) scale(1.25)');

      // Zooming back out at the same point returns to the initial view.
      fireEvent.wheel(viewport, {deltaY: 100, clientX: 100, clientY: 50});
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(1)');
    });

    it('resets zoom and pan via the reset button', () => {
      const {dialog, canvas, viewport} = openLightbox();

      fireEvent.click(within(dialog).getByRole('button', {name: 'Zoom in'}));
      fireEvent.pointerDown(viewport, {button: 0, pointerId: 1, clientX: 10, clientY: 10});
      fireEvent.pointerMove(viewport, {pointerId: 1, clientX: 40, clientY: 60});
      fireEvent.pointerUp(viewport, {pointerId: 1});
      expect(canvas.style.transform).toBe('translate(30px, 50px) scale(1.25)');

      fireEvent.click(within(dialog).getByRole('button', {name: 'Reset zoom'}));
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(1)');
    });
  });

  describe('pan', () => {
    it('pans the diagram by dragging', () => {
      const {canvas, viewport} = openLightbox();

      fireEvent.pointerDown(viewport, {button: 0, pointerId: 1, clientX: 100, clientY: 100});
      fireEvent.pointerMove(viewport, {pointerId: 1, clientX: 150, clientY: 80});
      expect(canvas.style.transform).toBe('translate(50px, -20px) scale(1)');

      fireEvent.pointerUp(viewport, {pointerId: 1});
      fireEvent.pointerMove(viewport, {pointerId: 1, clientX: 500, clientY: 500});
      expect(canvas.style.transform).toBe('translate(50px, -20px) scale(1)');
    });

    it('ignores drags that are not started with the primary button', () => {
      const {canvas, viewport} = openLightbox();

      fireEvent.pointerDown(viewport, {button: 2, pointerId: 1, clientX: 100, clientY: 100});
      fireEvent.pointerMove(viewport, {pointerId: 1, clientX: 150, clientY: 80});
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(1)');
    });

    it('only the pointer that started the drag pans the diagram', () => {
      const {canvas, viewport} = openLightbox();

      fireEvent.pointerDown(viewport, {button: 0, pointerId: 1, clientX: 100, clientY: 100});
      // A second touch must neither take over the drag ...
      fireEvent.pointerDown(viewport, {button: 0, pointerId: 2, clientX: 300, clientY: 300});
      fireEvent.pointerMove(viewport, {pointerId: 2, clientX: 400, clientY: 400});
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(1)');

      // ... nor end it when it lifts.
      fireEvent.pointerUp(viewport, {pointerId: 2});
      fireEvent.pointerMove(viewport, {pointerId: 1, clientX: 130, clientY: 90});
      expect(canvas.style.transform).toBe('translate(30px, -10px) scale(1)');

      fireEvent.pointerUp(viewport, {pointerId: 1});
    });
  });

  describe('focus trap', () => {
    it('traps Tab focus at the dialog edges', () => {
      const {dialog} = openLightbox();
      const buttons = within(dialog).getAllByRole('button');
      const first = buttons[0];
      const last = buttons[buttons.length - 1];

      last.focus();
      fireEvent.keyDown(dialog, {key: 'Tab'});
      expect(first).toHaveFocus();

      fireEvent.keyDown(dialog, {key: 'Tab', shiftKey: true});
      expect(last).toHaveFocus();
    });

    it('keeps focus inside when Shift+Tab is pressed on the dialog container itself', () => {
      const {dialog} = openLightbox();
      const buttons = within(dialog).getAllByRole('button');
      const last = buttons[buttons.length - 1];

      expect(dialog).toHaveFocus();
      fireEvent.keyDown(dialog, {key: 'Tab', shiftKey: true});
      expect(last).toHaveFocus();
    });
  });

  describe('initial fit-to-viewport zoom', () => {
    // jsdom has no ResizeObserver and reports all-zero element sizes, so both
    // are mocked: the observer to trigger the fit measurement manually, the
    // sizes to simulate a rendered diagram in a real viewport.
    let observerCallbacks;

    beforeEach(() => {
      observerCallbacks = [];
      vi.stubGlobal(
        'ResizeObserver',
        class {
          constructor(callback) {
            observerCallbacks.push(callback);
          }

          observe() {}

          disconnect() {}
        },
      );
    });

    afterEach(() => {
      vi.unstubAllGlobals();
    });

    function mockSizes({viewport, content}, sizes) {
      viewport.getBoundingClientRect = () => ({
        width: sizes.viewportWidth,
        height: sizes.viewportHeight,
        left: 0,
        top: 0,
      });
      Object.defineProperty(content, 'offsetWidth', {
        configurable: true,
        value: sizes.contentWidth,
      });
      Object.defineProperty(content, 'offsetHeight', {
        configurable: true,
        value: sizes.contentHeight,
      });
    }

    function openAndFit(sizes) {
      const utils = openLightbox();
      const content = screen.getByTestId('diagram-content');
      mockSizes({viewport: utils.viewport, content}, sizes);
      act(() => observerCallbacks.forEach((callback) => callback()));
      return utils;
    }

    it('scales the diagram up to fit the viewport once it has rendered', () => {
      const {canvas} = openAndFit({
        viewportWidth: 1000,
        viewportHeight: 800,
        contentWidth: 400,
        contentHeight: 300,
      });
      // min(1000/400, 800/300) * 0.9 margin = 2.25
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(2.25)');
    });

    it('caps the initial zoom at 400% for small diagrams', () => {
      const {dialog, canvas} = openAndFit({
        viewportWidth: 2000,
        viewportHeight: 1000,
        contentWidth: 100,
        contentHeight: 50,
      });
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(4)');
      expect(within(dialog).getByRole('button', {name: 'Reset zoom'})).toHaveTextContent('400%');
    });

    it('resets to the fitted zoom level, not to 100%', () => {
      const {dialog, canvas} = openAndFit({
        viewportWidth: 2000,
        viewportHeight: 1000,
        contentWidth: 100,
        contentHeight: 50,
      });
      fireEvent.click(within(dialog).getByRole('button', {name: 'Zoom in'}));
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(5)');

      fireEvent.click(within(dialog).getByRole('button', {name: 'Reset zoom'}));
      expect(canvas.style.transform).toBe('translate(0px, 0px) scale(4)');
    });

    it('does not override a zoom the user applied before the diagram rendered', () => {
      const utils = openLightbox();
      const content = screen.getByTestId('diagram-content');
      fireEvent.click(within(utils.dialog).getByRole('button', {name: 'Zoom in'}));

      mockSizes({viewport: utils.viewport, content}, {
        viewportWidth: 1000,
        viewportHeight: 800,
        contentWidth: 400,
        contentHeight: 300,
      });
      act(() => observerCallbacks.forEach((callback) => callback()));
      expect(utils.canvas.style.transform).toBe('translate(0px, 0px) scale(1.25)');
    });

    it('keeps 100% when the diagram has no measurable size yet', () => {
      const utils = openLightbox();
      act(() => observerCallbacks.forEach((callback) => callback()));
      expect(utils.canvas.style.transform).toBe('translate(0px, 0px) scale(1)');
    });
  });

  it('forwards extra props to the fullscreen rendering of the diagram', () => {
    render(<MermaidWrapper value={DIAGRAM} data-extra="kept" />);
    fireEvent.click(screen.getByRole('button', {name: 'Open diagram in fullscreen'}));
    const dialog = screen.getByRole('dialog', {name: 'Fullscreen diagram'});
    expect(within(dialog).getByTestId('mermaid-diagram')).toHaveAttribute('data-extra', 'kept');
  });
});
