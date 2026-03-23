// Entry point for the build script in your package.json
import {Application} from "@hotwired/stimulus"
const controllers = import.meta.glob("./**/*_controller.js", {eager: true})

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

Object.entries(controllers).forEach(([path, controllerModule]) => {
  const identifier = path.split("/").pop().replace("_controller.js", "").replace("_", "-") // optional: normalize kebab-case
  application.register(identifier, controllerModule.default)
})
