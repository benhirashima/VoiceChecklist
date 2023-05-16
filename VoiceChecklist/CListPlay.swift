//
//  CListPlay.swift
//  VoiceChecklist
//
//  Created by Ben Hirashima on 1/28/23.
//

import SwiftUI
import AVFoundation
import Speech

class VoiceManager: ObservableObject {
    @Binding var clist: CList
    @Published var isRunning: Bool
    @Published var isCanceled = false
    @Published var recogText = ""
    var voiceStyle: AVSpeechSynthesisVoice
    var speechSynth: AVSpeechSynthesizer
    var speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    var audioEngine: AVAudioEngine
    var audioSession: AVAudioSession
    private var isCheckHeard = false
    
    static func createVoiceManager(clist: Binding<CList>) -> VoiceManager {
        return VoiceManager(clist: clist, speechRecognizer: SFSpeechRecognizer()!, speechSynth: AVSpeechSynthesizer(), voiceStyle: AVSpeechSynthesisVoice(), audioEngine: AVAudioEngine(), audioSession: AVAudioSession())
    }
    
    init(clist: Binding<CList>, speechRecognizer: SFSpeechRecognizer, speechSynth: AVSpeechSynthesizer, voiceStyle: AVSpeechSynthesisVoice, audioEngine: AVAudioEngine, audioSession: AVAudioSession) {
        self._clist = clist
        self.speechRecognizer = speechRecognizer
        self.speechSynth = speechSynth
        self.voiceStyle = voiceStyle
        self.audioEngine = audioEngine
        self.audioSession = audioSession
        self.isRunning = false
    }
    
    @MainActor
    func startVoice() async {
        isRunning = true
        
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        func sayThis(string: String) {
            let utterance = AVSpeechUtterance(string: string)
            utterance.voice = voiceStyle
            speechSynth.speak(utterance)
        }
        
        func configRecogRequest() {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
            recognitionRequest.shouldReportPartialResults = true
            // Keep speech recognition data on device
            if #available(iOS 13, *) {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
        }
                    
        func startAudioSession() throws {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                self.recognitionRequest?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        }
        
        func cancelVoiceRecog() {
            self.audioEngine.stop()
            inputNode.removeTap(onBus: 0)
            self.recognitionRequest?.endAudio()
            self.recognitionRequest = nil
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
        }
        
        @Sendable
        func doTimeout() {
            self.isCanceled = true
            do
            {
                try audioSession.setActive(true)
                AudioServicesPlayAlertSound(1111)
                try audioSession.setActive(false)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
        
        if (speechRecognizer.isAvailable) {
            _ = Task() {
                for index in clist.items.indices {
                    if self.isCanceled { break }
                    
                    let item = self.clist.items[index]
                    if item.isChecked { continue }

                    sayThis(string: item.title)
                    
                    // stop listening after a while
                    let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { timer in
                        doTimeout()
                    }
                                            
                    configRecogRequest()
                    
                    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { result, error in
                        if (self.isCanceled) {
                            cancelVoiceRecog()
                        }
                        
                        var isFinal = false
                        
                        if let result = result {
                            self.recogText = result.bestTranscription.formattedString
                            isFinal = result.isFinal
                            print("Recognized text: \(result.bestTranscription.formattedString)")
                            
                            if let _ = self.recogText.range(of: "check", options: .caseInsensitive) {
                                self.isCheckHeard = true
                                print ("Check heard!")
                                self.clist.items[index].isChecked = true
                                timer.invalidate()
                            }
                        }
                        
                        if error != nil || isFinal || self.isCheckHeard {
                            cancelVoiceRecog()
                        }
                    }
                    
                    if self.isCanceled {
                        timer.invalidate()
                        break
                    }
                    
                    try startAudioSession()
                    
                    print("Waiting to hear check")
                    while isCheckHeard == false {
                        if self.isCanceled {
                            timer.invalidate()
                            cancelVoiceRecog()
                            break
                        }
                        try await Task.sleep(for: Duration(secondsComponent: 1, attosecondsComponent: 0))
                    }
                    isCheckHeard = false
                }
                isRunning = false
                if self.isCanceled {
                    self.isCanceled = false
                    return
                }
                sayThis(string: "End of checklist")
            }
        } else {
            print("Speech recognition unavailable")
            isRunning = false
        }
    }
}

struct CListPlay: View {
    @Binding var clist: CList
    @State private var newItemTitle = ""
    let saveClists: ()->Void
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    // we're not using the editMode environment variable because: https://medium.com/geekculture/swiftui-and-the-intermittent-editmode-b714c923f536
    @State var editMode: EditMode = .inactive
    @StateObject var voiceMan: VoiceManager
    let addCList: (CList?)->Void
    @FocusState private var isNewItemFieldFocused: Bool
       
    private func enterEditMode() {
        voiceMan.isCanceled = true
        editMode = .active
    }
    
    private func exitEditMode() {
        editMode = .inactive
        newItemTitle = ""
        isNewItemFieldFocused = false
        addCList(clist)
        saveClists()
    }
    
    private func addItem() {
        let newItem = CList.CListItem(title: newItemTitle)
        clist.items.append(newItem)
        newItemTitle = "" // clears new item TextField since it's databound to newItemTitle
        isNewItemFieldFocused = true
    }
        
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment :.leading, spacing: 5) {
                    Label {
                        TextField("Checklist title", text: $clist.title)
                            .font(.title)
                            .fontWeight(.light)
                            .disabled(editMode == .inactive)
                        
                    } icon : {
                        if editMode == .inactive {
                            let status = clist.getCheckedStatus()
                            Image(systemName: clist.getCheckIconName(status: status, differentiateWithoutColor: differentiateWithoutColor))
                                .foregroundColor(clist.getCheckIconColor(status: status))
                        }
                    }
                    if !clist.items.isEmpty || editMode == .active { // hide list if empty, otherwise we see a white area that we can't change the color of
                        List {
                            if editMode == .active {
                                ForEach($clist.items) { $item in
                                    TextField("Item Name", text: $item.title)
                                        .padding(.leading)
                                        .listRowBackground(Color(.clear))
                                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                }
                                .onDelete { indices in
                                    voiceMan.isCanceled = true
                                    clist.items.remove(atOffsets: indices)
                                }
                                .onMove { source, dest in
                                    voiceMan.isCanceled = true
                                    clist.items.move(fromOffsets: source, toOffset: dest)
                                }
                            } else {
                                // we are repeating the code below to work around a bug.
                                // the test for editMode cannot be inside the ForEach loop for some reason.
                                ForEach($clist.items) { $item in
                                    CheckboxView(item: $item)
                                            .listRowBackground(Color(.clear))
                                }
                                .onDelete { indices in
                                    voiceMan.isCanceled = true
                                    clist.items.remove(atOffsets: indices)
                                }
                                .onMove { source, dest in
                                    voiceMan.isCanceled = true
                                    clist.items.move(fromOffsets: source, toOffset: dest)
                                }
                            }
                            if editMode == .active {
                                HStack {
                                    TextField("New Item", text: $newItemTitle)
                                        .padding(.leading, 20.0)
                                        .focused($isNewItemFieldFocused)
                                        .onSubmit {
                                            withAnimation {
                                                addItem()
                                            }
                                        }
                                    Button(action: {
                                        withAnimation {
                                            addItem()
                                        }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                    }
                                    .disabled(newItemTitle.isEmpty)
                                    .foregroundColor(.accentColor)
                                }
                                .listRowBackground(Color(.clear))
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            }
                        }
                        .padding([.bottom, .trailing])
                        .listStyle(PlainListStyle())
                        .environment(\.editMode, $editMode)
                    } else {
                        Spacer()
                    }
                }
                .padding([.top, .leading])
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color("ThemeColor"), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .background(Color("ListBackgroundColor")) // background color outside the list view
                .fontWeight(.light)
                if editMode == .inactive {
                    Button(action: {
                        if voiceMan.isRunning {
                            voiceMan.isCanceled = true
                        } else {
                            SFSpeechRecognizer.requestAuthorization { authStatus in
                                DispatchQueue.main.async {
                                    if authStatus == .authorized {
                                        Task {
                                            await voiceMan.startVoice()
                                        }
                                    } else {
                                        print("Speech recognition denied")
                                    }
                                }
                            }
                        }
                    }) {
                        Image(systemName: voiceMan.isRunning ? "mic.fill.badge.xmark" : "mic")
                            .font(.system(size: 25))
                            .foregroundColor(.white)
                    }
                    .frame(width: 60, height: 60)
                    .background(Color("ThemeColor"))
                    .cornerRadius(30)
                    .shadow(radius: 3)
                    .offset(x: -30, y: -30)
                }
            }
            .toolbar {
                if editMode == .inactive {
                    Button(action: {
                        $clist.items.forEach { $item in
                            item.isChecked = false
                        }
                    }) {
                        Text("Reset")
                    }
                    Button(action: {
                        withAnimation {
                            enterEditMode()
                        }
                    }) {
                        Text("Edit")
                    }
                } else {
                    Button(action: {
                        if !newItemTitle.isEmpty { // save new item if something has been entered without tapping plus
                            let newItem = CList.CListItem(title: newItemTitle)
                            clist.items.append(newItem)
                        }
                        withAnimation {
                            exitEditMode()
                        }
                    }) {
                        Text("Done")
                    }
                    .disabled(clist.title.isEmpty || (clist.items.count == 0 && newItemTitle.isEmpty))
                }
            }
            .onAppear() {
                if clist.items.count == 0 {
                    enterEditMode()
                }
            }
            .onDisappear() {
                voiceMan.isCanceled = true
                saveClists()
            }
        }
    }
}

struct CListPlay_Previews: PreviewProvider {
    static var previews: some View {
        BindingProvider(CList.sampleData[0]) { binding in
            NavigationStack {
                CListPlay(clist: binding, saveClists: {}, voiceMan: VoiceManager.createVoiceManager(clist: binding), addCList: {_ in })
            }
        }
    }
}
