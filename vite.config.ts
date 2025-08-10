import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  // 👇 AÑADE ESTA LÍNEA EXACTAMENTE ASÍ 👇
  base: '/mascotas/', // Reemplaza 'mascotas' si tu repo tiene otro nombre

  plugins: [react()],
})