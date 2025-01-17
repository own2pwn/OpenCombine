//
//  TrackingSubscriber.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

/// `TrackingSubscriber` records every event like "receiveSubscription",
/// "receiveValue" and "receiveCompletion" into its `history` property,
/// optionally executing the provided callbacks.
///
/// This is useful when testing operators that somehow transform their upstream's output.
///
/// Note that `TrackingSubscriber.Event` is equatable, but doesn't respect
/// the subscription, in other words,
/// `TrackingSubscriber.Event.subscription(Subscription.empty)`
/// is considered equal to any other subscription no matter what the subscription object
/// actually is.
@available(macOS 10.15, *)
typealias TrackingSubscriber = TrackingSubscriberBase<TestingError>

/// `TrackingSubscriber` records every event like "receiveSubscription",
/// "receiveValue" and "receiveCompletion" into its `history` property,
/// optionally executing the provided callbacks.
///
/// This is useful when testing operators that somehow transform their upstream's output.
///
/// Note that `TrackingSubscriber.Event` is equatable, but doesn't respect
/// the subscription, in other words,
/// `TrackingSubscriber.Event.subscription(Subscription.empty)`
/// is considered equal to any other subscription no matter what the subscription object
/// actually is.
@available(macOS 10.15, *)
final class TrackingSubscriberBase<Failure: Error>: Subscriber, CustomStringConvertible {

    enum Event: Equatable, CustomStringConvertible {
        case subscription(Subscription)
        case value(Int)
        case completion(Subscribers.Completion<Failure>)

        static func == (lhs: Event, rhs: Event) -> Bool {
            switch (lhs, rhs) {
            case (.subscription, .subscription):
                return true
            case let (.value(lhs), .value(rhs)):
                return lhs == rhs
            case let (.completion(lhs), .completion(rhs)):
                switch (lhs, rhs) {
                case (.finished, .finished):
                    return true
                case let (.failure(lhs), .failure(rhs)):
                    return (lhs as? TestingError) == (rhs as? TestingError)
                default:
                    return false
                }
            default:
                return false
            }
        }

        var description: String {
            switch self {
            case .subscription:
                return "subscription"
            case .value(let value):
                return "value(\(value))"
            case .completion(.finished):
                return "finished"
            case .completion(.failure(let error)):
                return "failure(\(error))"
            }
        }
    }

    private let _receiveSubscription: ((Subscription) -> Void)?
    private let _receiveValue: ((Input) -> Subscribers.Demand)?
    private let _receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?
    private let _onDeinit: (() -> Void)?

    /// The history of subscriptions, inputs and completions of this subscriber
    private(set) var history: [Event] = []

    /// A lazy view on `history` with all events except subscriptions filtered out
    var subscriptions: LazyMapSequence<
        LazyFilterSequence<LazyMapSequence<[Event], Subscription?>>, Subscription
    > {
        return history.lazy.compactMap {
            if case .subscription(let s) = $0 {
                return s
            } else {
                return nil
            }
        }
    }

    /// A lazy view on `history` with all events except receiving input filtered out
    var inputs: LazyMapSequence<
        LazyFilterSequence<LazyMapSequence<[Event], Int?>>, Int
    > {
        return history.lazy.compactMap {
            if case .value(let v) = $0 {
                return v
            } else {
                return nil
            }
        }
    }

    /// A lazy view on `history` with all events except completions filtered out
    var completions: LazyMapSequence<
        LazyFilterSequence<
            LazyMapSequence<[Event], Subscribers.Completion<Failure>?>
        >,
        Subscribers.Completion<Failure>
    > {
        return history.lazy.compactMap {
            if case .completion(let c) = $0 {
                return c
            } else {
                return nil
            }
        }
    }

    init(receiveSubscription: ((Subscription) -> Void)? = nil,
         receiveValue: ((Input) -> Subscribers.Demand)? = nil,
         receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
         onDeinit: (() -> Void)? = nil) {
        _receiveSubscription = receiveSubscription
        _receiveValue = receiveValue
        _receiveCompletion = receiveCompletion
        _onDeinit = onDeinit
    }

    func receive(subscription: Subscription) {
        history.append(.subscription(subscription))
        _receiveSubscription?(subscription)
    }

    func receive(_ input: Int) -> Subscribers.Demand {
        history.append(.value(input))
        return _receiveValue?(input) ?? .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        history.append(.completion(completion))
        _receiveCompletion?(completion)
    }

    var description: String {
        return "\(type(of: self)): \(history)"
    }

    deinit {
        _onDeinit?()
    }
}

@available(macOS 10.15, *)
final class TrackingSubject: Subject {

    typealias Failure = TestingError

    typealias Output = Int

    enum Event: Equatable {
        case subscriber(CombineIdentifier)
        case value(Int)
        case completion(Subscribers.Completion<TestingError>)

        static func == (lhs: Event, rhs: Event) -> Bool {
            switch (lhs, rhs) {
            case let (.subscriber(lhs), .subscriber(rhs)):
                return lhs == rhs
            case let (.value(lhs), .value(rhs)):
                return lhs == rhs
            case let (.completion(lhs), .completion(rhs)):
                switch (lhs, rhs) {
                case (.finished, .finished):
                    return true
                case let (.failure(lhs), .failure(rhs)):
                    return lhs == rhs
                default:
                    return false
                }
            default:
                return false
            }
        }
    }

    private(set) var history: [Event] = []

    func send(_ value: Int) {
        history.append(.value(value))
    }

    func send(completion: Subscribers.Completion<TestingError>) {
        history.append(.completion(completion))
    }

    func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Failure == SubscriberType.Failure, Output == SubscriberType.Input
    {
        history.append(.subscriber(subscriber.combineIdentifier))
    }
}
