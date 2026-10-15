import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        'blue-primary': '#0A2A6B',
        'blue-deep': '#061A45',
        'blue-light': '#1E5EFF',
        'blue-surface': '#0D3585',
        'gold': '#D4AF37',
        'gold-light': '#F5D76E',
        'gold-dark': '#997A15',
        'yellow-custom': '#FFD60A',
        'alert-red': '#E5383B',
        'green-ok': '#10B981',
        'text-primary': '#F5F7FA',
        'text-secondary': '#A2B4D6',
        'text-muted': '#6C82A6',
      },
      boxShadow: {
        'glass': '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
        'gold-glow': '0 0 15px rgba(212, 175, 55, 0.35)',
        'alert-glow': '0 0 25px rgba(229, 56, 59, 0.6)',
      },
      animation: {
        'pulse-alarm': 'pulse 1.2s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      }
    },
  },
  plugins: [],
};

export default config;
