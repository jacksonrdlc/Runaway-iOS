# 🔐 API Key Setup Guide

## Quick Setup (Choose One Method)

### 🌟 **Recommended: Environment Variable**

1. **In Xcode:**
   - Go to **Product** → **Scheme** → **Edit Scheme**
   - Select **Run** → **Arguments** tab
   - Under **Environment Variables**, click **+**
   - Add:
     - **Name**: `RUNAWAY_API_KEY`
     - **Value**: `your-actual-api-key-here`

2. **Test the setup:**
   ```swift
   // This will print the current configuration
   APIConfiguration.RunawayCoach.printCurrentConfiguration()
   ```

### 🔧 **Alternative: Info.plist**

1. **Open Info.plist in Xcode**
2. **Add new key:**
   - **Key**: `RUNAWAY_API_KEY`
   - **Type**: String
   - **Value**: `your-actual-api-key-here`

### ⚡ **Quick Test: Hardcoded (Not for Production)**

1. **Edit APIConfiguration.swift:**
   ```swift
   // Replace this line:
   private static let hardcodedAPIKey: String? = nil
   
   // With your API key:
   private static let hardcodedAPIKey: String? = "your-api-key-here"
   ```

## 🧪 **Testing Your Setup**

Run this code to verify your API key is configured:

```swift
// Check configuration
APIConfiguration.RunawayCoach.printCurrentConfiguration()

// Test API connection
let testUtils = APITestUtils.shared
let result = await testUtils.testHealthCheck()
print("Health Check: \(result.success ? "✅" : "❌") - \(result.message)")
```

## 🔒 **Security Best Practices**

1. **Never commit API keys to source control**
2. **Use environment variables for development**
3. **Use secure storage for production apps**
4. **Rotate API keys regularly**
5. **Monitor API usage**

## 🐛 **Troubleshooting**

If you see `❌ Not Configured` in the configuration output:
1. Check spelling of `RUNAWAY_API_KEY`
2. Verify the key is not empty
3. Restart Xcode after adding environment variables
4. Check that Info.plist key is correctly formatted

## 📱 **Expected Output**

When correctly configured, you should see:
```
🔧 Runaway Coach API Configuration:
   Current URL: https://runaway-coach-api-203308554831.us-central1.run.app
   🔐 Authentication: ✅ Configured
   🔐 Auth Source: Environment Variable
```

## 🚀 **Ready to Go!**

Once configured, your app will automatically include the API key in all requests to your Runaway Coach API, enabling full agentic workflow capabilities!