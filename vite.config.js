import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      registerType: 'autoUpdate',
      manifest: {
        name: 'PedidosYa MVP',
        short_name: 'PedidosYa MVP',
        description: 'PWA de demostración para pedidos y logística',
        theme_color: '#e50046',
        background_color: '#ffffff',
        display: 'standalone',
        lang: 'es',
        icons: [
          {
            src: '/logos/logo.png',
            sizes: '778x732',
            type: 'image/png',
            purpose: 'any'
          }
        ]
      }
    })
  ]
})
