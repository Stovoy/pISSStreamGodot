# pISS Stream for Godot
Display how full the International Space Station's urine tank is on your toolbar in real time.

![Plugin Screenshot](screenshots/screenshot.png)

## Features
- Real-time ISS urine tank level monitoring
- Godot editor toolbar integration
- Visual progress bar with dynamic yellow intensity
- Emoji indicators (🚀🚽)
- Instant updates via WebSocket connection

## Installation
1. Create an `addons` folder in your Godot project if it doesn't exist
2. Download the `addons/pISSStreamGodot` folder from this repository and place it in your project's `addons` folder
3. Enable the plugin in Godot:
   - Go to Project → Project Settings → Plugins
   - Find "pISS Stream Godot" in the list
   - Check the "Enable" checkbox

## How It Works
The plugin connects to the ISS Live data feed through LightStreamer's WebSocket service to get real-time updates of the urine tank levels. It uses a custom minimal implementation of the LightStreamer Text-based Client Protocol (TLCP 2.4.0) to establish WebSocket connections and handle data streaming, since there wasn't an official GDScript client. The progress bar updates automatically and becomes more intensely yellow as the tank fills up.

## Credits
- Original idea: [Jaennaet/pISSStream](https://github.com/Jaennaet/pISSStream)
- Based on Unity implementation: [LeLocTai/pISSStreamUnity](https://github.com/LeLocTai/pISSStreamUnity)
- Godot implementation by [Stovoy](https://github.com/Stovoy)
- Data provided by [LightStreamer](https://demos.lightstreamer.com/ISSLive/)

## License
MIT License

## Contributing
Feel free to open issues or submit pull requests if you have suggestions for improvements or bug fixes.
