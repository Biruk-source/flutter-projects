# 🛠️ FixIt – A Community-Powered Maintenance & Reporting Platform

<p align="center">
  <img src="https://i.postimg.cc/4y96Dbt9/image.png" width="200">
</p>

<p align="center">
  <em>"The bridge between a problem seen and a problem solved."</em>
</p>

---

## 👨‍💻 About Me: The Mind Behind the Mission

My name is **Biruk Zewde**, and I am a passionate and relentlessly dedicated Flutter developer from Ethiopia 🇪🇹. I don't just write code; I strive to build solutions that have a tangible, positive impact on people's lives. I believe that technology's greatest purpose is to serve humanity, and I approach my work with a deep sense of responsibility and an unwavering commitment to quality.

This project, **FixIt**, is a testament to that belief. It's the product of countless hours of dedication, a collaborative spirit, and a burning desire to solve a real-world problem I saw in my own community. I am a builder, a problem-solver, and I am proud to present the culmination of my work.

---

## 🌍 The Problem: A Disconnect in Our Communities

In many neighborhoods, towns, and cities, a critical disconnect exists. A citizen sees a problem—a dangerous pothole, a broken streetlight, an overflowing garbage bin, a water leak—but has no clear, simple, or effective way to report it.

*   **Who do they call?**
*   **Will their report be heard or just lost in bureaucracy?**
*   **Will the problem ever actually be fixed?**

This communication breakdown leads to community neglect, delayed repairs, wasted resources, and a loss of public trust. Citizens feel unheard, and authorities lack an efficient system to track and manage these crucial maintenance tasks.

---

## 💡 Our Solution: FixIt - A Smart, Centralized Platform

**FixIt** is the answer. It is a comprehensive mobile application, built with **Flutter**, that creates a direct and transparent channel between the community and the authorities responsible for maintenance.

We empower every person to become the eyes and ears of their community. With FixIt, reporting an issue is as simple as taking a photo. The app intelligently captures all necessary details—location, description, and images—and delivers it to an admin dashboard where it can be tracked, managed, and resolved efficiently.

**FixIt transforms frustration into action and neglect into progress.**

---

## 🔥 Key Features & Capabilities

*   **📸 Intuitive Image-Based Reporting:** Users can quickly snap a photo of an issue.
*   **📍 Automatic Geolocation:** The app automatically tags the precise location of the problem using Google Maps.
*   **📝 Detailed Descriptions:** A simple form allows users to add crucial context and details.
*   **🔔 Real-Time Status Notifications:** Users are notified when their report is received, in-progress, and resolved, closing the feedback loop.
*   **📊 Powerful Admin Dashboard:** A dedicated interface for authorities to view, prioritize, assign, and manage all incoming reports in real-time.
*   **🔐 Secure User Authentication:** Safe and secure login/signup system powered by Firebase Auth.
*   **☁️ Reliable Cloud Infrastructure:** All data, from user reports to images, is securely stored and synchronized using Firebase Firestore and Storage.
*   **🎨 Clean & Accessible UI:** A user-friendly design that is intuitive for people of all ages and technical abilities.

---

## 📸 Application Screenshots: A Visual Tour

| **User Reporting Flow** | **Live Issue Map** | **Detailed Problem View** | **Comprehensive Admin Panel** |
| :---: | :---: | :---: | :---: |
| ![Report Form](https://i.postimg.cc/t4Ph7Tn3/photo-2025-03-30-06-45-26.jpg) | ![Map View](https://i.postimg.cc/7h63LnSh/Screenshot-2025-03-30-061601.png) | ![Details View](https://i.postimg.cc/c197bPNn/Screenshot-2025-03-30-061652.png) | ![Admin Panel](https://i.postimg.cc/1580hM9Y/Screenshot-2025-03-30-061718.png) |
| **Mobile Admin Access** | **FixIt Panel Overview** | **UI Flow Example** | **App Demo Snippet** |
| ![Mobile Admin](https://i.postimg.cc/15DT6DTX/photo-2025-06-15-22-12-29.jpg) | ![FixIt Panel](https://i.postimg.cc/Df9H8xxR/photo-2025-06-15-22-12-32.jpg) | ![UI Flow](https://i.postimg.cc/4y96Dbt9/image.png) | ![App Demo](https://i.postimg.cc/QN9JKsPd/image.png) |

---

## 🧑‍💻 Our Team & My Role: A Story of Collaboration

This project was a true partnership, built on a foundation of mutual respect and shared goals. I worked alongside my talented teammate, **Gemechue**. Here is a breakdown of our responsibilities:

### **Biruk Zewde (My Contributions):**
As the lead Flutter developer, I was responsible for bringing the vision to life.
*   **Frontend Architecture & UI/UX:** I designed and developed the entire user-facing application from the ground up using Flutter, focusing on a clean, responsive, and intuitive user experience.
*   **Firebase Integration:** I engineered the complete backend integration with Firebase, including Authentication for user management, Firestore for the real-time database, and Cloud Storage for handling all image uploads.
*   **Google Maps API:** I implemented the Google Maps functionality, enabling precise geolocation tagging and the visualization of reported issues on an interactive map.
*   **State Management:** I structured the app's state using Provider to ensure predictable and maintainable data flow.
*   **Core App Logic:** I wrote the logic for user workflows, including the reporting process, notifications, and data synchronization.

### **Gemechue (Project Partner):**
Gemechue was instrumental in the project's success, focusing on the strategic and backend logic.
*   **System Architecture & Logic Planning:** He played a key role in designing the overall application architecture and the logic for how data would be managed.
*   **Admin Panel Functionality:** He was crucial in defining the requirements and workflow for the admin dashboard.
*   **Firebase Security Rules:** He helped structure the security rules to ensure that data access was properly restricted between users and admins.
*   **Quality Assurance & Testing:** He rigorously tested the application to identify bugs and ensure a stable user experience.

---

## 🔧 Technology Stack & Architectural Choices

We chose our technologies carefully to build a robust, scalable, and real-time application.

| Technology | Purpose & Reason for Choice |
| :--- | :--- |
| **Flutter** | Chosen for its ability to create beautiful, high-performance, natively compiled applications for mobile from a single codebase. Its "hot reload" feature dramatically sped up UI development and iteration. |
| **Firebase Auth** | Selected for its robust, secure, and easy-to-implement user authentication system, handling everything from sign-up to password resets. |
| **Cloud Firestore** | The heart of our app. Chosen for its real-time NoSQL database capabilities, allowing the admin panel and user apps to stay perfectly in sync without manual refreshing. |
| **Firebase Storage** | The ideal solution for storing user-generated content like images. It's secure, scalable, and integrates seamlessly with the rest of the Firebase ecosystem. |
| **Provider** | Chosen as our state management solution for its simplicity and effectiveness in managing the app's state in a way that is easy to understand and maintain. |
| **Google Maps API**| The industry standard for mapping. We used it to provide accurate location data and a familiar, interactive map interface for our users. |

---

## ⚙️ How to Set Up and Run This Project

To explore the code or contribute, follow these steps:

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/Biruk-source/fixit-app.git
    ```

2.  **Navigate to the Project Directory:**
    ```bash
    cd fixit-app
    ```

3.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

4.  **Set Up Firebase:**
    *   You will need to create your own Firebase project.
    *   Add your `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) files to the appropriate directories.

5.  **Run the Application:**
    ```bash
    flutter run
    ```

---

## 🔗 Connect With Me

I am always open to connecting with fellow developers, potential collaborators, or anyone interested in my work.

*   **Email:** `boomshakalakab13@gmail.com`
*   **GitHub:** [Biruk-source](https://github.com/Biruk-source)
*   **Portfolio:** *(Add Your Portfolio Link Here)*

---

## 📄 License

This project is licensed under the MIT License. Feel free to use, study, and improve upon it. All I ask is that if you use my work, you give credit where it's due. This project was built with hustle and heart.

**MIT License** © 2025 **Biruk Zewde**
