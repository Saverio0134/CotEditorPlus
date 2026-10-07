//
//  DocumentWindow.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2014-10-31.
//
//  ---------------------------------------------------------------------------
//
//  © 2014-2026 1024jp
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AppKit
import Defaults
import Shortcut
import ControlUI

final class DocumentWindow: NSWindow {
    
    // MARK: Public Properties
    
    var contentBackgroundColor: NSColor = .controlBackgroundColor {
        
        didSet {
            guard
                !self.isOpaque,
                contentBackgroundColor != oldValue
            else { return }
            
            self.applyBackgroundOpacity()
        }
    }
    
    @objc dynamic var backgroundAlpha: Double = 1.0 {
        
        didSet {
            backgroundAlpha.clamp(to: 0.2...1.0)
            
            guard
                !self.styleMask.contains(.fullScreen),
                backgroundAlpha != oldValue
            else { return }
            
            self.applyBackgroundOpacity()
        }
    }
    
    
    // MARK: Public Methods
    
    /// Applies the current background opacity to the window.
    func applyBackgroundOpacity() {
        
        let shouldBeOpaque = (self.backgroundAlpha == 1.0)
        
        if self.isOpaque != shouldBeOpaque {
            self.isOpaque = shouldBeOpaque
        }
        self.backgroundColor = shouldBeOpaque ? nil : self.contentBackgroundColor.withAlphaComponent(self.backgroundAlpha)
        
        self.invalidateShadow()
        self.contentView?.needsDisplay = true
    }
    
    
    // MARK: Window Methods
    
    override static var restorableStateKeyPaths: [String] {
        
        super.restorableStateKeyPaths + [#keyPath(backgroundAlpha), #keyPath(level)]
    }
    
    
    override static func allowedClasses(forRestorableStateKeyPath keyPath: String) -> [AnyClass] {
        
        switch keyPath {
            case #keyPath(backgroundAlpha), #keyPath(level):
                [NSNumber.self]
            default:
                super.allowedClasses(forRestorableStateKeyPath: keyPath)
        }
    }
    
    
    override var isOpaque: Bool {
        
        willSet { self.willChangeValue(for: \.isOpaque) }
        didSet { self.didChangeValue(for: \.isOpaque) }
    }
    
    
    override func becomeKey() {
        
        super.becomeKey()
        
        self.setupCloseButton()
    }
    
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        
        self.attachToExistingWindowIfPossible()
        super.makeKeyAndOrderFront(sender)
    }
    
    
    override func orderFront(_ sender: Any?) {
        
        self.attachToExistingWindowIfPossible()
        super.orderFront(sender)
    }
    
    
    override func performClose(_ sender: Any?) {
        
        // Terminate the application when clicking the window's red close button (🔴)
        // to behave like Cmd+Q, preserving unsaved documents without per-document save sheets.
        if let button = sender as? NSButton, button == self.standardWindowButton(.closeButton) {
            NSApp.terminate(nil)
            return
        }
        
        super.performClose(sender)
    }
    
    
    // MARK: Actions
    
    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        
        switch item.action {
            case #selector(toggleKeepOnTop):
                (item as? any StatableItem)?.state = self.isFloating ? .on : .off
                
            case #selector(NSWindow.moveTabToNewWindow):
                return false
                
            default:
                break
        }
        
        return super.validateUserInterfaceItem(item)
    }
    
    
    /// Toggle the window level between normal and floating.
    @IBAction func toggleKeepOnTop(_ sender: Any?) {
        
        self.isFloating.toggle()
    }
    
    
    /// Disallow moving tabs to separate windows (single-window application only).
    @IBAction override func moveTabToNewWindow(_ sender: Any?) {
        
        // No-op
    }
    
    
    // MARK: Internal Methods
    
    /// Sets up the window's standard close button to terminate the application.
    func setupCloseButton() {
        
        self.standardWindowButton(.closeButton)?.target = NSApp
        self.standardWindowButton(.closeButton)?.action = #selector(NSApplication.terminate(_:))
    }
    
    
    /// Attaches the window to the existing tab group so that only a single window exists.
    func attachToExistingWindowIfPossible() {
        
        guard self.tabbingMode != .disallowed else { return }
        
        if let existingWindow = NSApp.windows.compactMap({ $0 as? DocumentWindow }).first(where: { $0 != self && $0.isVisible && $0.tabbingMode != .disallowed }) {
            if self.tabGroup == nil || self.tabGroup !== existingWindow.tabGroup {
                existingWindow.addTabbedWindow(self, ordered: .above)
            }
        }
    }
    
    
    // MARK: Private Methods
    
    /// Whether the window level is floating.
    private var isFloating: Bool {
        
        get { self.level == .floating }
        set { self.level = newValue ? .floating : .normal }
    }
}


// MARK: Window Tabbing

extension DocumentWindow {
    
    /// The temporal tabbing preference (remember to set it to `nil` after use).
    static var tabbingPreference: NSWindow.UserTabbingPreference?
    
    
    // MARK: Window Methods
    
    override class var userTabbingPreference: NSWindow.UserTabbingPreference {
        
        .always
    }
    
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        
        guard !super.performKeyEquivalent(with: event) else { return true }
        
        // select tabbed window with `⌘-number` (`⌘9` for the last tab)
        if
            self.tabbingMode != .disallowed,
            let shortcut = Shortcut(keyDownEvent: event),
            shortcut.modifiers == [.command],
            shortcut.keyEquivalent.count == 1,
            let number = Int(shortcut.keyEquivalent), number > 0,
            let group = self.tabGroup,
            let window = (number == 9) ? group.windows.last : group.windows[safe: number - 1]  // 1-based to 0-based
        {
            // prefer existing shortcut that user might define
            guard NSApp.mainMenu?.performKeyEquivalent(with: event) != true else { return true }
            
            group.selectedWindow = window
            return true
        }
        
        return false
    }
}
