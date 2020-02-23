To-Do List
==========

- scheduling solution
    - this should provide a solution for all server->device interaction
        - downlinks
        - periodic/on-demand actions
        - failsafe stuff / server-side back-off
        
- basic-station protocol integration
    - Semtech UDP format is great for testing but lack of gateway authentication
      means you shouldn't deploy it
    - basic station provides a solution, integrating will likely
      require some work be done on routing to/from websockets
        - this feature should be paired with cluster mode since both
          are to benefit production environments

- refactor Device
    - more mixins?
    
- solution for managing channel plans
    - presently they are fixed at start-time
    - what happens if you remove or change a plan a device is referencing?

- more diagnostics
    - also, diagnostics which can be turned on at run-time

- review the effect of timing on when Redis records are updated

- cluster mode
    it should be possible to have a master process spawn a bunch of workers
    much like how Puma does it
    
- more testing    
    - need to implement a "dummy gateway" that will make it possible
      to exercise the full server end-to-end
    - could implement a Semtech format client but this protocol makes
      things more complicated and only to the benefit of over testing
      the Semtech format
      
- logging
    - the logger_methods make a mess out of this, need to refactor

- need to check how much time has passed at the point where the deferred
  queue is processed to prevent peculiar behavior under load.

- support custom messages through some kind of plugin/extension pattern
