/**
 * SmartGas Design System - Shared Tokens (TypeScript)
 * Source of truth: shared/tokens/theme.json
 */

export const themeTokens = {
  palette: {
    primary: {
      blue: '#0A2A6B',
      blueDeep: '#061A45',
      blueLight: '#1E5EFF',
      blueSurface: '#0D3585',
      blueGlass: 'rgba(10, 42, 107, 0.65)',
    },
    accent: {
      gold: '#D4AF37',
      goldLight: '#F5D76E',
      goldDark: '#997A15',
      yellow: '#FFD60A',
      yellowHover: '#E6C200',
    },
    gradients: {
      goldGauge: {
        start: '#F5D76E',
        end: '#D4AF37',
      },
      surfaceDeep: {
        start: '#0A2A6B',
        end: '#061A45',
      },
      alertCritical: {
        start: '#E5383B',
        end: '#8F1D20',
      },
    },
    status: {
      critical: '#E5383B',
      warning: '#FFD60A',
      info: '#1E5EFF',
      success: '#10B981',
    },
    text: {
      primary: '#F5F7FA',
      secondary: '#A2B4D6',
      muted: '#6C82A6',
      inverse: '#061A45',
    },
    border: {
      subtle: 'rgba(212, 175, 55, 0.25)',
      gold: '#D4AF37',
      focus: '#FFD60A',
    },
  },
  typography: {
    fontFamily: {
      sans: 'Inter, system-ui, -apple-system, sans-serif',
      mono: 'JetBrains Mono, Menlo, monospace',
    },
  },
  shadows: {
    glass: '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
    goldGlow: '0 0 15px rgba(212, 175, 55, 0.35)',
    alertGlow: '0 0 25px rgba(229, 56, 59, 0.6)',
  },
} as const;

export type ThemeTokens = typeof themeTokens;
