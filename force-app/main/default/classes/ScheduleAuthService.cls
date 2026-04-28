global class ScheduleAuthService implements Schedulable {

    global void execute(SchedulableContext sc) {
        System.enqueueJob(new ShelfwatchAuthRefreshQueue());
    }
}