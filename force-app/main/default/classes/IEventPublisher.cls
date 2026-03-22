/**
 * IEventPublisher
 *
 * SOLID — Interface Segregation Principle (I):
 *   A small, focused interface responsible for one thing: publishing events.
 *   Classes that need to publish events depend on this abstraction only,
 *   not on a larger service interface.
 *
 * SOLID — Dependency Inversion Principle (D):
 *   High-level modules (e.g. ServiceAppointmentTriggerHandler) depend on this
 *   abstraction, not on EventBus directly. This allows mock injection in tests.
 */
public interface IEventPublisher {
    void publish(List<SObject> events);
}
