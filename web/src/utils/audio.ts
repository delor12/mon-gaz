class SoundSynthesizer {
  private ctx: AudioContext | null = null;
  private oscillator: OscillatorNode | null = null;
  private isPlaying = false;

  private initContext() {
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      this.ctx = new AudioCtx();
    }
    if (this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  playCriticalAlarm() {
    try {
      this.initContext();
      if (!this.ctx || this.isPlaying) return;

      this.isPlaying = true;
      this.oscillator = this.ctx.createOscillator();
      const gainNode = this.ctx.createGain();

      this.oscillator.type = 'sawtooth';
      this.oscillator.frequency.setValueAtTime(750, this.ctx.currentTime);
      this.oscillator.frequency.exponentialRampToValueAtTime(1800, this.ctx.currentTime + 0.35);

      gainNode.gain.setValueAtTime(0.3, this.ctx.currentTime);

      this.oscillator.connect(gainNode);
      gainNode.connect(this.ctx.destination);

      this.oscillator.start();
      setTimeout(() => {
        if (this.oscillator) {
          this.oscillator.stop();
          this.oscillator.disconnect();
          this.oscillator = null;
        }
        this.isPlaying = false;
      }, 350);
    } catch (e) {
      console.warn('Audio autoplay blocked by browser policy:', e);
    }
  }

  stop() {
    if (this.oscillator) {
      try {
        this.oscillator.stop();
        this.oscillator.disconnect();
      } catch (e) {
        // ignore
      }
      this.oscillator = null;
    }
    this.isPlaying = false;
  }
}

export const soundSynthesizer = new SoundSynthesizer();
