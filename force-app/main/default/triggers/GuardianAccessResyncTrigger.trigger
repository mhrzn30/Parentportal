trigger GuardianAccessResyncTrigger on Guardian_Access_Resync__e(after insert) {
  GuardianAccessResyncHandler.handle(Trigger.new);
}
