//
//  ContentView.swift
//  Fleeting
//
//  Created by Shriram Vasudevan on 4/14/25.
//

import SwiftUI
import CoreData

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var journalManager: JournalStorageManager
    @State private var showingWordCountView = false
    @State private var scrolledDate: Date?
    @State private var currentTheme: DailyTheme
    @State private var previousTheme: DailyTheme?
    @State private var isTransitioning = false
    @State private var transitionProgress: CGFloat = 0

    @State private var fontSize: CGFloat = 18
    @State private var selectedFont: String = "Lato-Regular"
    @State private var hoveredFont: String? = nil
    @State private var isHoveringSize = false

    @State private var isHoveringBottomNav = false
    @State private var bottomNavOpacity: Double = 1.0

    let fontOptions = ["Lato-Regular", "Arial", "Times New Roman", "Menlo"]
    let fontSizes: [CGFloat] = [14, 16, 18, 20, 22, 24]
    
    // For gesture handling
    @GestureState private var dragState = DragState.inactive
    @State private var currentOffset: CGFloat = 0

    init() {
        // Pick a random pulsing bokeh theme at launch.
        _currentTheme = State(initialValue: DailyTheme.randomTheme())
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base background color.
                (themeManager.isDarkMode ? Color.black : Color.white)
                    .ignoresSafeArea()
                
                // Animated pulsing bokeh background.
                currentTheme.patternOverlay
                    .opacity(themeManager.isDarkMode ? 1.0 : 1.0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: themeManager.isDarkMode)
                
                VStack(spacing: 0) {
                    HStack {
                        Text("fleeting.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        
                        Spacer()
                    }
                    
                    ScrollViewReader { scrollView in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 40) {
                                VStack {
                                    Spacer(minLength: 120)
                                    
                                    TextField("write.", text: $journalManager.currentEntry, axis: .vertical)
                                        .font(.custom(selectedFont, size: fontSize))
                                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                                        .placeholder(when: journalManager.currentEntry.isEmpty) {
                                            Text("write.")
                                                .font(.custom(selectedFont, size: 16))
                                                .foregroundColor(themeManager.isDarkMode ?
                                                    Color.white.opacity(0.5) :
                                                    Color.black.opacity(0.5))
                                                .multilineTextAlignment(.center)
                                        }
                                        .multilineTextAlignment(.center)
                                        .frame(width: 400)
                                        .padding(.horizontal, 40)
                                        .background(Color.clear)
                                        .textFieldStyle(PlainTextFieldStyle())
                                    
                                    if !journalManager.currentEntry.isEmpty {
                                        Text(formattedDateWithDay(Date()))
                                            .font(.system(size: 13, weight: .light))
                                            .foregroundColor(themeManager.isDarkMode ?
                                                Color.white.opacity(0.6) :
                                                Color.black.opacity(0.6))
                                            .padding(.top, 12)
                                    }
                                    
                                    Spacer(minLength: 200)
                                }
                                .id("current")
                                .transition(.opacity)
                                .offset(y: currentOffset)
                                .gesture(
                                    DragGesture()
                                        .updating($dragState) { value, state, _ in
                                            state = .dragging(translation: value.translation)
                                        }
                                        .onEnded { value in
                                            if !journalManager.currentEntry.isEmpty {
                                                journalManager.saveCurrentEntry()
                                            }
                                            
                                            if value.translation.height > 50 {
                                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                    navigateToPreviousDay()
                                                }
                                            } else {
                                                withAnimation { currentOffset = 0 }
                                            }
                                        }
                                )
                                
                                ForEach(journalManager.entries) { entry in
                                    EntryView(entry: entry, fontSize: fontSize - 2, fontName: selectedFont)
                                        .id(entry.id)
                                        .onAppear {
                                            if scrolledDate != entry.createdAt {
                                                scrolledDate = entry.createdAt
                                                updateTheme()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .onAppear {
                            scrollView.scrollTo("current", anchor: .center)
                        }
                    }
                }
                .offset(y: dragState.translation?.height ?? 0)
                
                VStack {
                    Spacer()
                    bottomNavigationBar
                }
            }
            .onAppear { updateTheme() }
        }
        .onDisappear { journalManager.saveCurrentEntry() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            journalManager.saveCurrentEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            journalManager.saveCurrentEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
            journalManager.loadEntries()
        }
        .sheet(isPresented: $showingWordCountView) { WordCountView() }
    }
    
    // MARK: - Bottom Navigation Bar

    private var bottomNavigationBar: some View {
        HStack {
            HStack(spacing: 12) {
                Button("\(Int(fontSize))px") {
                    let currentIndex = fontSizes.firstIndex(of: fontSize) ?? 0
                    fontSize = fontSizes[(currentIndex + 1) % fontSizes.count]
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(isHoveringSize ?
                                 (themeManager.isDarkMode ? .white : .black) :
                                 (themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)))
                .font(.system(size: 13))
                .onHover { hovering in
                    isHoveringSize = hovering
                    isHoveringBottomNav = hovering
                }
                
                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                
                ForEach(fontOptions, id: \.self) { font in
                    Button(getFontDisplayName(font)) { selectedFont = font }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(getFontColor(font))
                        .font(.system(size: 13))
                        .onHover { hovering in
                            hoveredFont = hovering ? font : nil
                            isHoveringBottomNav = hovering
                        }
                    
                    if font != fontOptions.last {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 18) {
                Button { showingWordCountView.toggle() } label: {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button { themeManager.toggleTheme() } label: {
                    Image(systemName: themeManager.isDarkMode ? "sun.max" : "moon")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .padding(.bottom, 10)
        .background(themeManager.isDarkMode ? Color.black.opacity(0.7) : Color.white.opacity(0.85))
        .opacity(bottomNavOpacity)
        .onHover { hovering in
            isHoveringBottomNav = hovering
            withAnimation(.easeOut(duration: 0.2)) { bottomNavOpacity = hovering ? 1.0 : 0.8 }
        }
    }
    
    // MARK: - Theme & Navigation Helpers

    private func updateTheme() {
        previousTheme = currentTheme
        let newTheme = DailyTheme.randomTheme()
        if newTheme.id != currentTheme.id {
            isTransitioning = true
            currentTheme = newTheme
            withAnimation(.easeInOut(duration: 0.8)) { transitionProgress = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isTransitioning = false
                transitionProgress = 0
            }
        }
    }
    
    private func navigateToPreviousDay() {
        currentOffset = 0
        let sortedEntries = journalManager.entries.sorted { $0.createdAt > $1.createdAt }
        let calendar = Calendar.current
        let today = Date()
        if let todayIndex = sortedEntries.firstIndex(where: { calendar.isDate($0.createdAt, inSameDayAs: today) }),
           todayIndex + 1 < sortedEntries.count {
            let previousEntry = sortedEntries[todayIndex + 1]
            scrolledDate = previousEntry.createdAt
            updateTheme()
        }
    }
    
    private func formattedDateWithDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func getFontDisplayName(_ font: String) -> String {
        switch font {
        case "Lato-Regular": return "Lato"
        case "Times New Roman": return "Serif"
        case ".AppleSystemUIFont": return "System"
        default: return font
        }
    }
    
    private func getFontColor(_ font: String) -> Color {
        if font == selectedFont {
            return themeManager.isDarkMode ? .white : .black
        } else if hoveredFont == font {
            return themeManager.isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9)
        } else {
            return themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
        }
    }
}

// MARK: - Drag State Enum

enum DragState {
    case inactive
    case dragging(translation: CGSize)
    var translation: CGSize? {
        switch self {
        case .inactive: return nil
        case .dragging(let translation): return translation
        }
    }
}

// MARK: - Entry View

struct EntryView: View {
    let entry: JournalEntry
    let fontSize: CGFloat
    let fontName: String
    @EnvironmentObject private var themeManager: ThemeManager
    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            Text(entry.content)
                .font(.custom(fontName, size: fontSize))
                .multilineTextAlignment(.center)
                .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                .padding(.horizontal, 40)
                .lineSpacing(4)
            Text(formattedDateWithDay(entry.createdAt))
                .font(.system(size: 13, weight: .light))
                .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                .padding(.top, 8)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }
    private func formattedDateWithDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Word Count View
// (Your existing JournalStorageManager & JournalEntry models are assumed unchanged.)

struct WordCountView: View {
    @EnvironmentObject private var journalManager: JournalStorageManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    private var wordCountData: [(date: Date, count: Int)] {
        journalManager.getWordCountsByDate()
    }
    private var maxCount: Int {
        wordCountData.map { $0.count }.max() ?? 0
    }
    private var totalWords: Int {
        wordCountData.reduce(0) { $0 + $1.count }
    }
    private var averageWords: Int {
        wordCountData.isEmpty ? 0 : totalWords / wordCountData.count
    }
    private var longestStreak: Int {
        guard !wordCountData.isEmpty else { return 0 }
        let sortedDates = wordCountData.map { $0.date }.sorted()
        var currentStreak = 1, maxStreak = 1
        for i in 1..<sortedDates.count {
            let previousDate = sortedDates[i-1]
            let currentDate = sortedDates[i]
            let daysBetween = Calendar.current.dateComponents([.day], from: previousDate, to: currentDate).day ?? 0
            if daysBetween == 1 {
                currentStreak += 1
                maxStreak = max(currentStreak, maxStreak)
            } else if daysBetween > 1 {
                currentStreak = 1
            }
        }
        return maxStreak
    }
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Writing Activity")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            .padding([.top, .horizontal], 20)
            
            HStack(spacing: 20) {
                StatBlock(title: "Total", value: "\(totalWords)", icon: "text.word.count", isDarkMode: themeManager.isDarkMode)
                StatBlock(title: "Average", value: "\(averageWords)", icon: "chart.bar.fill", isDarkMode: themeManager.isDarkMode)
                StatBlock(title: "Streak", value: "\(longestStreak)", icon: "flame.fill", isDarkMode: themeManager.isDarkMode)
            }
            .padding(.horizontal)
            
            if wordCountData.isEmpty {
                Text("No writing data available yet")
                    .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.5) : .gray)
                    .padding()
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(wordCountData, id: \.date) { item in
                            VStack(spacing: 5) {
                                Text("\(item.count)")
                                    .font(.system(size: 11))
                                    .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.5) : .gray)
                                Rectangle()
                                    .fill(Color.blue.opacity(themeManager.isDarkMode ? 0.6 : 0.7))
                                    .frame(width: 8, height: calculateBarHeight(for: item.count))
                                Text(formatDate(item.date))
                                    .font(.system(size: 10))
                                    .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.5) : .gray)
                                    .rotationEffect(.degrees(-45))
                                    .frame(width: 30)
                                    .offset(y: 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 25)
                    .padding(.top, 15)
                }
                .frame(height: 250)
                .padding()
            }
        }
        .frame(width: 450, height: 340)
        .background(themeManager.isDarkMode ? Color.black : Color.white)
    }
    private func calculateBarHeight(for count: Int) -> CGFloat {
        guard maxCount > 0 else { return 0 }
        return max(CGFloat(count) / CGFloat(maxCount) * 180, 12)
    }
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

struct StatBlock: View {
    let title: String, value: String, icon: String, isDarkMode: Bool
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
            Text(value)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isDarkMode ? .white : .black)
            Text(title)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
        }
        .frame(minWidth: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDarkMode ? Color.black.opacity(0.3) : Color.white.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Daily Theme & Pulsing Bokeh Circles Variants

struct DailyTheme: Identifiable, Equatable {
    var id: String
    var patternOverlay: AnyView
    static func == (lhs: DailyTheme, rhs: DailyTheme) -> Bool { lhs.id == rhs.id }
    
    /// Returns a random pulsing circles theme.
    static func randomTheme() -> DailyTheme {
        return themes.randomElement() ?? themes[0]
    }
    
    /// Two new beautiful pulsing bokeh circles variants.
    static let themes: [DailyTheme] = [
        DailyTheme(id: "bokehCircles1", patternOverlay: AnyView(BokehCirclesVariant1())),
        DailyTheme(id: "bokehCircles2", patternOverlay: AnyView(BokehCirclesVariant2()))
    ]
}

/// Variant 1 – Scattered bokeh circles with a gentle drift and slow pulsation.
struct BokehCirclesVariant1: View {
    let circleCount: Int = 60
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for i in 0..<circleCount {
                        let fi = Double(i)
                        // Compute stable positions using trigonometric functions.
                        let baseX = size.width * (0.3 + 0.4 * (sin(fi * 1.37) * 0.5 + 0.5))
                        let baseY = size.height * (0.3 + 0.4 * (cos(fi * 1.73) * 0.5 + 0.5))
                        // Apply a subtle drift.
                        let driftX = 10 * CGFloat(sin(time * 0.1 + fi))
                        let driftY = 10 * CGFloat(cos(time * 0.1 + fi))
                        let center = CGPoint(x: baseX + driftX, y: baseY + driftY)
                        
                        // Base radius between 10 and 20.
                        let baseRadius = CGFloat(10 + 10 * (sin(fi * 0.5) * 0.5 + 0.5))
                        // Slow pulse.
                        let scale = 1.0 + 0.2 * CGFloat(sin(time * 0.2 + fi))
                        let radius = baseRadius * scale
                        
                        let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)
                        // Use a soft radial gradient: center light, edges transparent.
                        let gradient = Gradient(stops: [
                            .init(color: Color.gray.opacity(0.15), location: 0.0),
                            .init(color: Color.gray.opacity(0), location: 1.0)
                        ])
                        let radialGradient = RadialGradient(gradient: gradient, center: .center, startRadius: 0, endRadius: radius)
                        context.fill(Path(ellipseIn: circleRect), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))

                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// Variant 2 – A denser bokeh pattern with a slightly different drift and pulse.
struct BokehCirclesVariant2: View {
    let circleCount: Int = 80
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for i in 0..<circleCount {
                        let fi = Double(i)
                        let baseX = size.width * (0.2 + 0.6 * (cos(fi * 1.11) * 0.5 + 0.5))
                        let baseY = size.height * (0.2 + 0.6 * (sin(fi * 1.53) * 0.5 + 0.5))
                        let driftX = 8 * CGFloat(sin(time * 0.15 + fi * 0.7))
                        let driftY = 8 * CGFloat(cos(time * 0.15 + fi * 0.7))
                        let center = CGPoint(x: baseX + driftX, y: baseY + driftY)
                        
                        let baseRadius = CGFloat(8 + 8 * (cos(fi * 0.3) * 0.5 + 0.5)) // between 8 and 16
                        let scale = 1.0 + 0.15 * CGFloat(sin(time * 0.25 + fi * 0.9))
                        let radius = baseRadius * scale
                        
                        let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)
                        let gradient = Gradient(stops: [
                            .init(color: Color.gray.opacity(0.12), location: 0.0),
                            .init(color: Color.gray.opacity(0), location: 1.0)
                        ])
                        let radialGradient = RadialGradient(gradient: gradient, center: .center, startRadius: 0, endRadius: radius)
                        context.fill(Path(ellipseIn: circleRect), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))

                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Helper Extension for Placeholder

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content) -> some View {
            ZStack(alignment: alignment) {
                placeholder().opacity(shouldShow ? 1 : 0)
                self
            }
        }
}


// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = false
    func toggleTheme() { isDarkMode.toggle() }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ThemeManager())
            .environmentObject(JournalStorageManager.shared)
    }
}
