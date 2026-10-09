<div class="landing">
  <div class="eyebrow">COMMON LISP · DECLARATIVE TUI · THE ELM ARCHITECTURE</div>
  <h1>Interfaces for the <em>terminal-native</em> world.</h1>
  <p class="lead">ElmTUI is a declarative Common Lisp terminal UI framework. Describe your interface, transform state through messages, compose widgets and let the renderer handle the screen.</p>
  <div class="hero-actions">
    <a class="hero-primary" href="quickstart/">Build your first app ↗</a>
    <a class="hero-secondary" href="workbench/">Explore the Workbench →</a>
  </div>
  <div class="hero-feature-label">THE ELM TUI WORKBENCH <span>Flagship application · release qualification in progress</span></div>
  <div class="media-stage hero-shot" role="img" aria-label="ElmTUI Workbench terminal REPL with completion popup and image inspector" data-preview="assets/workbench-hero.webp">
    <div class="window-top"><span class="window-indicator"></span> ELMTUI / LISP WORKBENCH <span class="window-right">SBCL · CL-USER</span></div>
    <div class="shot-placeholder">
      <div class="mock-main"><span class="mock-dim">;;; A live Common Lisp environment</span><br><br><span class="mock-prompt">CL-USER&gt;</span> (mapcar #'1+ '(1 2 3))<br><span class="mock-result">(2 3 4)</span><br><br><span class="mock-prompt">CL-USER&gt;</span> (describe 'defun)<span class="mock-caret">▌</span><br><br><span class="mock-complete">▸ DEFUN &nbsp; Define a function<br>&nbsp; DEFMACRO &nbsp; Define a macro</span></div>
      <div class="mock-side">IMAGE INSPECTOR<br><br><span>Packages</span><br>Symbols<br>ASDF systems<br>Diagnostics<br><br><span>INSPECTION</span></div>
    </div>
    <span class="preview-caption">WORKBENCH SCREENSHOT SLOT · website/assets/workbench-hero.webp</span>
  </div>
  <div class="feature-grid">
    <div><span class="feature-kicker">01 / ARCHITECTURE</span><h3>Model → Update → View</h3><p>Keep events, state transitions and terminal rendering separate. Use commands for external effects.</p></div>
    <div><span class="feature-kicker">02 / COMPOSITION</span><h3>Build with widgets</h3><p>Structured layouts, input, focus, scrollable views, styled controls and reusable components.</p></div>
    <div><span class="feature-kicker">03 / RENDERING</span><h3>Change only what changed</h3><p>Virtual buffers and diff-based presentation avoid needless terminal output when the frame is unchanged.</p></div>
  </div>
  <div class="section-intro"><span class="eyebrow">A FRAMEWORK BUILT TO MOVE</span><h2>Animated, responsive, composable.</h2><p>Your upcoming terminal-slider animation belongs here, beside the source and keyboard controls that demonstrate it.</p></div>
  <div class="media-stage motion-stage" role="img" aria-label="Animated terminal slider interaction" data-preview="assets/terminal-slider.gif">
    <div class="motion-placeholder"><span class="motion-bars">▁ ▃ ▅ ▇ ▅ ▃ ▁</span><br><span>TERMINAL SLIDER / ANIMATION PREVIEW</span><br><small>Drop your GIF in website/assets/terminal-slider.gif</small></div>
    <span class="preview-caption">ANIMATED DEMO SLOT · website/assets/terminal-slider.gif</span>
  </div>
  <div class="bottom-cta"><h2>From a pure state transition<br>to a complete terminal application.</h2><a class="hero-primary" href="quickstart/">Read the getting-started guide ↗</a></div>
</div>
