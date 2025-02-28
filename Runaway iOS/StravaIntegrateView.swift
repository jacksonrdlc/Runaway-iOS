import SwiftUI

struct StravaIntegrateView: View {
    @State private var isStravaAuthenticated: Bool = false
    @StateObject private var stravaAuthService = StravaAuthService.shared
    
    var body: some View {
        VStack {
                    Button {
                        stravaAuthService.login()
                    } label: {
                        Image("Strava")
                    }
                }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StravaIntegrateView_Previews: PreviewProvider {
    static var previews: some View {
        StravaIntegrateView()
    }
}
