<a id="readme-top"></a>

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/othneildrew/Best-README-Template">
    <img src="assets/images/icon.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">SakayLive</h3>

  <p align="center">
    Real-time Jeepney & Bus Tracking App for Iloilo City
    <br />
    <a href="https://github.com/stepanmonster/SakayLive"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/stepanmonster/SakayLive">View Demo</a>
    &middot;
    <a href="https://github.com/stepanmonster/SakayLive/issues/new?labels=bug&template=bug-report---.md">Report Bug</a>
    &middot;
    <a href="https://github.com/stepanmonster/SakayLive/issues/new?labels=enhancement&template=feature-request---.md">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#project-structure">Project Structure</a></li>
    <li><a href="#troubleshooting">Troubleshooting</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

SakayLive is a modern mobile application designed to help commuters in Iloilo City navigate the public transport system with ease. It provides real-time tracking of jeepneys and buses, route planning, and estimated arrival times (ETAs).

Key Features:
*   **Real-Time Tracking**: See the exact location of buses and jeepneys on the map.
*   **Trip Planning**: Get efficient routes from point A to point B, including walking and transfers.
*   **Live ETA**: Know exactly when your ride will arrive, adjusted for traffic conditions.
*   **Route Visualization**: View colorful route lines and stops on the map.
*   **Simulation Mode**: (For Developers) Test routing and tracking with simulated bus movements.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Built With

* [![Flutter][Flutter.dev]][Flutter-url]
* [![Dart][Dart.dev]][Dart-url]
* [![Firebase][Firebase.com]][Firebase-url]
* [![Mapbox][Mapbox.com]][Mapbox-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

To get a local copy up and running follow these simple example steps.

### Prerequisites

* Flutter SDK
  ```sh
  flutter doctor
  ```
* Mapbox Access Token
* Firebase Project

### Installation

1. Get a Mapbox API Key at [https://mapbox.com](https://mapbox.com)
2. Clone the repo
   ```sh
   git clone https://github.com/stepanmonster/SakayLive.git
   ```
3. Install packages
   ```sh
   flutter pub get
   ```
4. Configure Environment Variables
   Create a `.env` file in the root directory and add your keys:
   ```env
   MAPBOX_ACCESS_TOKEN=your_mapbox_access_token_here
   ```
5. Configure Firebase
   - Add your `google-services.json` to `android/app/`.
   - Add your `GoogleService-Info.plist` to `ios/Runner/` (if iOS is supported).

6. Run the app
   ```sh
   flutter run
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage

### Commuter Mode
1.  Open the app and grant location permissions.
2.  See nearby buses and routes.
3.  Use the search bar to plan a trip to a destination.
4.  View step-by-step navigation with walking and boarding instructions.

### Developer / Demo Mode
1.  Open the side drawer.
2.  Toggle "Demo Mode" to use a simulated location.
3.  Use "Debug Tools" -> "Add Fake Buses" to simulate traffic for testing.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- PROJECT STRUCTURE -->
## Project Structure

Here's an overview of the project's file structure to help you get oriented:

```bash
sakaylive/
├── android/            # Android native code & configuration
├── assets/             # Application assets
│   ├── fonts/          # Custom fonts (Poppins)
│   ├── images/         # Icons and UI images
│   └── routes/         # GeoJSON files for route paths
├── lib/
│   ├── data/           # Static data and repositories
│   ├── models/         # Data models (Vehicle, Route, Trip)
│   ├── screens/        # UI Screens (Map, Search, Navigation)
│   ├── services/       # Business logic (MapDrawing, VehicleTracking)
│   ├── utils/          # Helper functions and constants
│   ├── viewmodels/     # State management (Provider)
│   ├── widgets/        # Reusable UI components
│   └── main.dart       # App entry point
├── .env                # Environment variables (API Keys)
└── pubspec.yaml        # Project dependencies
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- TROUBLESHOOTING -->
## Troubleshooting

Common issues and how to fix them:

**1. Map tiles are not loading / Black screen**
*   Ensure your `MAPBOX_ACCESS_TOKEN` in the `.env` file is correct and has `downloads:read` scope if required.
*   Check your internet connection.

**2. "Permission Denied" error in console**
*   This usually relates to Firebase Realtime Database.
*   Ensure your `google-services.json` is in `android/app/`.
*   Check Firebase Console > Realtime Database > Rules. For development, you might need to set read/write to `true` (use with caution).

**3. Location not updating**
*   **Emulator:** Use "Extended Controls" > "Location" to simulate movement.
*   **Real Device:** Ensure Location Services are on and permissions are granted to the app.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ROADMAP -->
## Roadmap

- [x] Basic Route Visualization
- [x] Real-time Firebase Vehicle Tracking
- [x] Trip Planning Algorithm
- [x] Mapbox Integration
- [ ] Conductor App for GPS broadcasting
- [ ] Push Notifications for Arrivals
- [ ] Offline Mode for Schedules
- [ ] Multi-language Support

See the [open issues](https://github.com/stepanmonster/SakayLive/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- LICENSE -->
## License

Distributed under the MIT License.

```text
MIT License

Copyright (c) 2026 stepanmonster

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Christian Joseph Hernia - herniachristianjoseph@gmail.com

Project Link: [https://github.com/stepanmonster/SakayLive](https://github.com/stepanmonster/SakayLive)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [Flutter](https://flutter.dev)
* [Mapbox](https://mapbox.com)
* [Firebase](https://firebase.google.com)
* [Best-README-Template](https://github.com/othneildrew/Best-README-Template)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/stepanmonster/SakayLive.svg?style=for-the-badge
[contributors-url]: https://github.com/stepanmonster/SakayLive/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/stepanmonster/SakayLive.svg?style=for-the-badge
[forks-url]: https://github.com/stepanmonster/SakayLive/network/members
[stars-shield]: https://img.shields.io/github/stars/stepanmonster/SakayLive.svg?style=for-the-badge
[stars-url]: https://github.com/stepanmonster/SakayLive/stargazers
[issues-shield]: https://img.shields.io/github/issues/stepanmonster/SakayLive.svg?style=for-the-badge
[issues-url]: https://github.com/stepanmonster/SakayLive/issues
[license-shield]: https://img.shields.io/github/license/stepanmonster/SakayLive.svg?style=for-the-badge
[license-url]: https://github.com/stepanmonster/SakayLive/blob/master/LICENSE.txt
[product-screenshot]: images/screenshot.png
[Flutter.dev]: https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white
[Flutter-url]: https://flutter.dev/
[Dart.dev]: https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white
[Dart-url]: https://dart.dev/
[Firebase.com]: https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black
[Firebase-url]: https://firebase.google.com/
[Mapbox.com]: https://img.shields.io/badge/Mapbox-000000?style=for-the-badge&logo=mapbox&logoColor=white
[Mapbox-url]: https://mapbox.com/
