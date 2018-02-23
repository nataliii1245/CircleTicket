//
//  ViewController.swift
//  CircleTicket
//
//  Created by Наталия Волкова on 17.02.2018.
//  Copyright © 2018 natalii. All rights reserved.
//

import Cocoa
import SwiftSocket

class ViewController: NSViewController {

    // MARK: - Outlets
    
    // View блока запуска сервера
    @IBOutlet weak var startServerView: NSView!
    // IP-адрес сервера
    @IBOutlet weak var serverIPAddressStartServerTextField: NSTextField!
    // IP-адрес получателя
    @IBOutlet weak var recepientIPAddressStartServerTextField: NSTextField!
    // Номер порта
    @IBOutlet weak var numOfPortStartServerTextField: NSTextField!
    // Кнопка "Запустить сервер"
    @IBOutlet weak var startServerButton: NSButton!
    // Кнопка "Остановить"
    @IBOutlet weak var stopServerButton: NSButton! {
        willSet {
            newValue.isEnabled = false
        }
    }
    
    // View блока отправки тикета
    @IBOutlet weak var sendCircleTicketView: NSView!
    // IP-адрес сервера
    @IBOutlet weak var serverIPAddressSendCircleTicketTextField: NSTextField!
    // Номер порта
    @IBOutlet weak var numOfPortSendCircleTicketrTextField: NSTextField!
    // Стартовый тикет
    @IBOutlet weak var startTicketTextField: NSTextField!
    // Кнопка "Отправить тикет"
    @IBOutlet weak var sendCircleTicketButton: NSButton!
    
    // Окно вывода логов
    @IBOutlet weak var logScrollView: NSTextView! {
        willSet {
            newValue.isEditable = false
        }
    }
    
    
    // MARK: - Приватные свойства
    
    let queue = DispatchQueue(label: "ru.nataliii.queue", qos: .utility, attributes: .concurrent)
    
    private var server: TCPServer?
    
}


// MARK: - NSViewController

extension ViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureBlocks()
        
    }
    
}


// MARK: - IBActions

extension ViewController {
    
    @IBAction func stopServerButtonClicked(_ sender: NSButton) {
        self.server?.close()
        self.server = nil
        
        sender.isEnabled = false
        self.startServerButton.isEnabled = true
    }
    
    @IBAction func sendTicketButtonPressed(_ sender: NSButton) {
        let startToken = startTicketTextField.integerValue
        let serverIp = serverIPAddressSendCircleTicketTextField.stringValue
        let numberOfPort = numOfPortSendCircleTicketrTextField.intValue
        
        self.queue.async {
            self.clientMode(startToken: startToken, suffix: "\r\n", recepientIP:serverIp, port: numberOfPort)
        }
    }
    
    @IBAction func runServerButtonPressed(_ sender: NSButton) {
        let serverIp = serverIPAddressStartServerTextField.stringValue
        let recepientIp = recepientIPAddressStartServerTextField.stringValue
        let numberOfPort = numOfPortSendCircleTicketrTextField.intValue
        
        self.queue.async {
            self.serverMode(serverIp: serverIp, recepientIP: recepientIp, port: numberOfPort)
        }
        
        sender.isEnabled = false
        self.stopServerButton.isEnabled = true
    }
    
}


// MARK: - Публичные методы

extension ViewController {
    
    func configureBlocks() {
        
        self.startServerView.wantsLayer = true
        self.sendCircleTicketView.wantsLayer = true
        
        self.startServerView.layer?.backgroundColor = CGColor(red:0.81, green:0.81, blue:0.81, alpha:1.0)
        self.sendCircleTicketView.layer?.backgroundColor = CGColor(red:0.81, green:0.81, blue:0.81, alpha:1.0)
        
        self.startServerView.layer?.cornerRadius = 10
        self.sendCircleTicketView.layer?.cornerRadius = 10
    }

    func log(message: String) {
        DispatchQueue.main.async {
            self.logScrollView.string += message + "\n"
            self.logScrollView.scrollToEndOfDocument(self)
        }
    }
    
    func serverMode(serverIp: String, recepientIP: String, port: Int32) {
        self.server?.close()
        
        let server = TCPServer(address: serverIp, port: port)
        self.server = server
        
        switch server.listen() {
        case .success:
            while server.fd != nil {
                guard let client = server.accept() else {
                    let message = "Ошибка в процессе подключения клиента"
                    log(message: message)
                    
                    continue
                }
                var message = "Подключен новый клиент: \(client.address)"
                log(message: message)
                
                guard let bytes = client.read(1024 * 10) else {
                    let message = "Ошибка получения данных от клиента"
                    log(message: message)
                    
                    continue
                }
                
                client.close()
                
                let data = Data(bytes)
                guard let string = String(data: data, encoding: .ascii) else {
                    let message = "Ошибка парсинга данных от клиента"
                    log(message: message)
                    
                    continue
                }
                
                let suffix = "\r\n"
                guard let number = Int(string.replacingOccurrences(of: suffix, with: "")) else {
                    let message = "Ошибка получения токена клиента"
                    log(message: message)
                    
                    continue
                }
                
                let newNumber = number + 1
               
                message = "Получено число: \(number)" + "\n" + "Отправлено число: \(newNumber)"
                log(message: message)
                
                NSSound.beep()
                
                self.queue.asyncAfter(deadline: .now() + .milliseconds(500)) {
                    self.clientMode(startToken: newNumber, suffix: suffix, recepientIP: recepientIP, port: port)
                }
            }
        case .failure(let error):
            print(error)
        }
    }
    
    func clientMode(startToken: Int,suffix: String, recepientIP: String, port: Int32) {
        
        let newClient = TCPClient(address: recepientIP, port: port)
        switch newClient.connect(timeout: 10) {
        case .success:
            let string = "\(startToken)\(suffix)"
            
            guard let result = string.data(using: .ascii) else {
                let message = "Ошибка создания токена"
                log(message: message)
                
                return
            }
            switch newClient.send(data: result) {
            case .success:
                let message = "Успешно!"
                log(message: message)
                
            case .failure(let error):
                let message = error.localizedDescription
                log(message: message)
            }
            
            newClient.close()
        case .failure(let error):
            let message = error.localizedDescription
            log(message: message)
        }
    }
    
}
