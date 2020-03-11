To-Do List
==========

- scheduling solution
    - this should provide a solution for all server->device interaction
        - downlinks
        - periodic/on-demand actions
        - failsafe stuff / server-side back-off
        
- refactor Device
    - more mixins?
    
- more diagnostics
    - also, diagnostics which can be turned on at run-time

- review the effect of timing on when Redis records are updated

- cluster mode
    it should be possible to have a master process spawn a bunch of workers
    much like how Puma does it
    
- more testing    
    - need to add end-to-end testing
      
- need to check how much time has passed at the point where the deferred
  queue is processed to prevent peculiar behavior under load.

- support custom messages through some kind of plugin/extension pattern
