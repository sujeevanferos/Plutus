# Plutus - Student Finance Tracker & AI Advisor

Plutus is a modern, Flutter-based mobile application designed to help students manage their finances effectively. It combines intuitive expense tracking with the power of Artificial Intelligence to provide personalized financial advice.

Built with Flutter, Plutus ensures a smooth, cross-platform experience with a focus on privacy and local data storage.

## 🚀 Key Features

### 💰 Transaction Management
- **Easy Entry**: Quickly add income and expenses with titles, amounts, and categories.
- **Categorization**: Pre-defined categories for students (e.g., Tuition, Rent, Food, transport, Scholarship, Part-time Job).
- **Recent Activity**: View your latest transactions at a glance on the dashboard.

### 📊 Visual Analytics
- **Dashboard Overview**: Instant view of your Net Balance.
- **Interactive Charts**: Visualize your spending habits with daily, weekly, and monthly bar charts.
- **Expense Breakdown**: Understand where your money goes with detailed pie charts.

### 🤖 AI Financial Advisor
- **Powered by Gemini**: Integrated with Google's Gemini API.
- **Personalized Advice**: Ask questions like "How can I save more on food?" and get answers based on your *actual* spending data.
- **Context-Aware**: The AI analyzes your income, expenses, and balance to provide relevant tips.

### ⚙️ Settings & Customization
- **Theme Support**: Toggle between Light and Dark modes for comfortable viewing.
- **Data Privacy**: All transaction data is stored locally on your device.
- **Data Export**: Export your transaction history to CSV format (Daily, Weekly, Monthly, or Yearly).
- **App Reset**: Securely wipe all data with an option to backup first.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: `setState` & `StatefulWidget` (Simple and effective for this scale)
- **Local Storage**: `shared_preferences`
- **Charting**: `fl_chart`
- **Networking**: `http`
- **AI Integration**: Google Gemini API
- **Formatting**: `intl`, `flutter_markdown`

## 🏁 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- A code editor (VS Code, Android Studio).
- A Google Gemini API Key (Get one [here](https://aistudio.google.com/app/apikey)).

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/plutus.git
    cd plutus
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    ```bash
    flutter run
    ```

### 🔑 API Key Setup (Crucial for AI Features)

To use the AI Financial Advisor, you need to configure your Gemini API Key:

1.  Open the app and navigate to **Settings** (top-right gear icon).
2.  Scroll down to the **API Configuration** section.
3.  Enter your Gemini API Key in the field provided.
4.  The key is saved locally, and the AI Advisor tab will now be active.

## 📱 Usage Guide

1.  **Adding a Transaction**:
    - Go to the **Dashboard** tab.
    - Fill in the Title, Amount, select Type (Income/Expense), and Category.
    - Tap **Add Transaction**.

2.  **Viewing Analytics**:
    - Switch to the **Analysis** tab (Pie Chart icon).
    - Toggle between Daily, Weekly, and Monthly views to see trends.
    - Check the Pie Chart for category-wise distribution.

3.  **Getting Advice**:
    - Switch to the **Advisor** tab (Brain icon).
    - Ensure your API Key is set.
    - Type a question (e.g., "Analyze my spending this week") and tap **Get Advice**.

4.  **Exporting Data**:
    - Go to **Settings**.
    - Tap on **Export to CSV**.
    - Select the time range you want to export.
    - The file will be saved to your device's Downloads or Documents folder.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
