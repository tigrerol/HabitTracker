import SwiftUI
import Combine

struct TimerView: View {
    let duration: TimeInterval // in seconds
    let onTimerComplete: () -> Void
    
    @State private var remainingTime: TimeInterval
    @State private var timer: AnyCancellable?
    @State private var isRunning: Bool = false
    
    init(duration: TimeInterval, onTimerComplete: @escaping () -> Void) {
        self.duration = duration
        self.onTimerComplete = onTimerComplete
        _remainingTime = State(initialValue: duration)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text(timeString(from: remainingTime))
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
            
            HStack(spacing: 16) {
                Button {
                    if isRunning {
                        pauseTimer()
                    } else {
                        startTimer()
                    }
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .orange : .green)
                
                Button {
                    resetTimer()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
        .onDisappear {
            timer?.cancel()
        }
    }
    
    private func startTimer() {
        isRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if remainingTime > 0 {
                    remainingTime -= 1
                } else {
                    timer?.cancel()
                    isRunning = false
                    onTimerComplete()
                }
            }
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.cancel()
    }
    
    private func resetTimer() {
        pauseTimer()
        remainingTime = duration
    }
    
    private func timeString(from time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView(duration: 300) {
            print("Timer finished!")
        }
    }
}
