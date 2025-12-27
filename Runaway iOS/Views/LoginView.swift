import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.largeTitle)
                .padding(.bottom, 30)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .padding()
                .onAppear {
                    email = "jackrudelic@gmail.com"
                }
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onAppear {
                            password = "password"
                        }
            
            Button(action: {
                Task {
                    do {
                        if isSignUp {
                            try await userSession.signUp(email: email, password: password)
                        } else {
                            try await userSession.signIn(email: email, password: password)
                        }
                    } catch {
                        showError = true
                        errorMessage = error.localizedDescription
                    }
                }
            }) {
                Text(isSignUp ? "Sign Up" : "Sign In")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()
            
            Button(action: { isSignUp.toggle() }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .foregroundColor(.blue)
            }
            }
            .padding()
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(AppTheme.Colors.LightMode.background.ignoresSafeArea())
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}
