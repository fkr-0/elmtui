<div class="landing">
  <div class="eyebrow">COMMON LISP · DECLARATIVE TUI · THE ELM ARCHITECTURE</div>
  <h1>Interfaces for the <em>terminal-native</em> world.</h1>
  <p class="lead">ElmTUI is a declarative Common Lisp terminal UI framework. Describe your interface, transform state through messages, compose widgets and let the renderer handle the screen.</p>
  <div class="hero-actions">
    <a class="hero-primary" href="quickstart/">Build your first app ↗</a>
    <a class="hero-secondary" href="workbench/">Explore the Workbench →</a>
  </div>
  <div class="hero-feature-label">THE ELM TUI WORKBENCH <span>Flagship application · shipped in 0.3.1</span></div>
  <div class="media-stage hero-shot" role="img" aria-label="ElmTUI Workbench terminal REPL" data-preview="assets/workbench.gif">
    <div class="window-top"><span class="window-indicator"></span> ELMTUI / LISP WORKBENCH <span class="window-right">SBCL · CL-USER</span></div>
    <div class="shot-placeholder">
      <div class="mock-main"><span class="mock-dim">;;; A live Common Lisp environment</span><br><br><span class="mock-prompt">CL-USER&gt;</span> (mapcar #'1+ '(1 2 3))<br><span class="mock-result">(2 3 4)</span><br><br><span class="mock-prompt">CL-USER&gt;</span> (describe 'defun)<span class="mock-caret">▌</span><br><br><span class="mock-complete">▸ DEFUN &nbsp; Define a function<br>&nbsp; DEFMACRO &nbsp; Define a macro</span></div>
      <div class="mock-side">IMAGE INSPECTOR<br><br><span>Packages</span><br>Symbols<br>ASDF systems<br>Diagnostics<br><br><span>INSPECTION</span></div>
    </div>
    <span class="preview-caption">LISP WORKBENCH · transcript, symbol completion and image inspector</span>
  </div>
  <div class="hero-feature-label hero-feature-label--secondary">MORE EXAMPLES <span>Interactive demos shipped with the framework</span></div>
  <div class="hero-duo">
    <div class="media-stage duo-cell" role="img" aria-label="Tmux Glider animation" data-preview="assets/tmux-glider.gif">
      <div class="triptych-placeholder"><span class="motion-bars">▁ ▃ ▅ ▇</span><br>TMUX GLIDER</div>
      <span class="triptych-label">tmux-glider</span>
    </div>
    <div class="media-stage duo-cell" role="img" aria-label="Neon Tetris game" data-preview="assets/neon-tetris.gif">
      <div class="triptych-placeholder"><span style="font-size:1.6rem">⬛⬜⬜⬛</span><br>NEON TETRIS</div>
      <span class="triptych-label">neon-tetris</span>
    </div>
  </div>
  <div class="feature-grid">
    <div><span class="feature-kicker">01 / ARCHITECTURE</span><h3>Model → Update → View</h3><p>Keep events, state transitions and terminal rendering separate. Use commands for external effects.</p></div>
    <div><span class="feature-kicker">02 / COMPOSITION</span><h3>Build with widgets</h3><p>Structured layouts, input, focus, scrollable views, styled controls and reusable components.</p></div>
    <div><span class="feature-kicker">03 / RENDERING</span><h3>Change only what changed</h3><p>Virtual buffers and diff-based presentation avoid needless terminal output when the frame is unchanged.</p></div>
  </div>
  <div class="section-intro"><span class="eyebrow">A FRAMEWORK BUILT TO MOVE</span><h2>Animated, responsive, composable.</h2><p>The tmux slider sweeps a colour band across a live tmux pane and restores every cell behind it. Arrow keys reverse it and change its speed; Space pauses. More recordings are in the <a href="examples/">examples gallery</a>.</p></div>
  <div class="media-stage motion-stage" role="img" aria-label="Animated terminal slider interaction" data-preview="assets/terminal-slider.gif">
    <div class="motion-placeholder"><span class="motion-bars">▁ ▃ ▅ ▇ ▅ ▃ ▁</span><br><span>TERMINAL SLIDER / ANIMATION PREVIEW</span><br><small>scripts/examples.sh run tmux-slider</small></div>
    <span class="preview-caption">TMUX SLIDER · scripts/examples.sh run tmux-slider</span>
  </div>
  <div class="bottom-cta"><h2>From a pure state transition<br>to a complete terminal application.</h2><a class="hero-primary" href="quickstart/">Read the getting-started guide ↗</a></div>
</div>
