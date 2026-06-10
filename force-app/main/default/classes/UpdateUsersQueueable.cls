public class UpdateUsersQueueable implements Queueable {
    private List<User> usersToUpdate;

    public UpdateUsersQueueable(List<User> users) {
        this.usersToUpdate = users;
    }

    public void execute(QueueableContext context) {
        if (usersToUpdate == null || usersToUpdate.isEmpty()) {
            return;
        }
        // allOrNone = false : a single bad User row must not roll back the rest of the batch.
        // During a bulk Employee data upload one failing User update previously discarded
        // every other User sync even though the Employee rows were already committed.
        Database.SaveResult[] results = Database.update(usersToUpdate, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(LoggingLevel.ERROR,
                    'User sync failed for Id ' + usersToUpdate[i].Id + ': ' + results[i].getErrors());
            }
        }
    }
}
