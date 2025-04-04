import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    historyApiFallback: true, // Habilita el history API fallback para desarrollo
  },
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'), // Asegura el manejo correcto de rutas en producción
      },
    },
    outDir: 'dist', // Asegura que la build vaya a la carpeta que Netlify espera
  },
  optimizeDeps: {
    exclude: ['lucide-react'],
  },
});
