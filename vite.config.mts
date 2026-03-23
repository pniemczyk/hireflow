import {defineConfig} from "vite"
import ViteRails from "vite-plugin-rails"
import tailwindcss from "@tailwindcss/vite"
import {VitePWA} from "vite-plugin-pwa"
import path from "path"
const viteDomain = process.env.VITE_DOMAIN || "apl.localhost"

const joinPath = (...args) => path.join(__dirname, ...args)

export default defineConfig({
  plugins: [
    tailwindcss(),
    ViteRails({
      envVars: {RAILS_ENV: "development", NODE_ENV: "development", VITE_DOMAIN: viteDomain},
      envOptions: {defineOn: "import.meta.env"},
      stimulus: {appGlobal: "$$StimulusApp$$"},
      fullReload: {
        additionalPaths: ["config/routes.rb", "app/helpers/**/*", "app/views/**/*", "app/frontend/**/*"],
        delay: 300,
      },
    }),
    VitePWA({
      disable: process.env.NODE_ENV !== "production",
      registerType: "autoUpdate",
      devOptions: {
        enabled: false,
      },
      workbox: {
        clientsClaim: true,
        skipWaiting: true,
      },
    }),
  ],
  build: {
    manifest: true,
    sourcemap: true,
  },
  resolve: {
    extensions: [".js", ".jsx", ".json", ".css", ".scss"],
    alias: {
      "@": joinPath("app/frontend"),
    },
  },
  optimizeDeps: {
    include: ["@hotwired/stimulus"],
  },
  server: {
    port: 3066,
    strictPort: true,
    hmr: {
      protocol: "wss",
      clientPort: 443,
      // protocol: "ws",
      // clientPort: 9112,
      host: viteDomain
    },
  },
})
