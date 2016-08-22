import salt.config
import salt.utils.event
import os
import time

opts = salt.config.client_config('/etc/salt/master')

event = salt.utils.event.get_event(
        'master',
        sock_dir=opts['sock_dir'],
        transport=opts['transport'],
        opts=opts)

os.system('cls' if os.name == 'nt' else 'clear')

start_time = None
for event_data in event.iter_events(tag='formula_status'):
    if start_time == None:
        start_time = time.time()
    data, tag = event_data["data"], event_data["tag"]
    progress_curr = data.get("progress_curr", False)
    progress_max = data.get("progress_max", False)

    if progress_curr and progress_max:
        print "Formula Progress:", (float(progress_curr) / float(progress_max)) * 100, "%", data.get("message", ""), "-", int(time.time() - start_time), "s"
    else:
        print data.get("message", "Status updated!"), "-", int(time.time() - start_time), "s"
