const plugins = import.meta.glob("./**/*_plugin.js", {eager: true})
import {createIcons, icons} from "lucide"

const initializeApp = () => {
  Object.entries(plugins).forEach(([path, pluginModule]) => {
    const identifier = path.split("/").pop().replace("_plugin.js", "").replace("-", "_") // optional: normalize kebab-case

    try {
      pluginModule.default.init()
    } catch (error) {
      console.error(`Error initializing plugin ${identifier}:`, error)
    }
  })
  createIcons({icons})
}

document.addEventListener("turbo:frame-load", initializeApp)
document.addEventListener("turbo:load", initializeApp)
// TODO: It seems that this event is triggered twice, once for the stream and once for the target. We need to check if the target is already rendered before dispatching the event.
document.addEventListener("turbo:stream-rendered", initializeApp)
