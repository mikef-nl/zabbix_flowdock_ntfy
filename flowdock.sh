#!/usr/bin/env python
"""Zabbix Action Alert Script for CA Flowdock.

This module sends messages to Flowdock API. 
The alerts contain links to the following areas within Zabbix.
Trigger Descriptions
Past Events for the Trigger
Acknowledgement form for the Trigger
URL Link for URL Defined in the Trigger
"""
import re
import sys
import json
import logging
import requests


class ZabbixAlert(object):
    """Parses Zabbix message and formats it for consumption by Flowdock API.

    Attributes:
        images(okimg, probimg): Provide the URLs for images to use as icons
                                for OK and PROBLEM states.
        sendmsg(): Sends the formatted JSON to the Flowdock API endpoint.

    """

    HEADERS = {'Content-Type': 'application/json'}
    zabbix_url = <YOUR ZABBIX URL HERE>
    logging.basicConfig(filename='/var/log/flowdock',level=logging.INFO,filemode = 'w')

    def __init__(self, token, subject, message):
        """
        The __init__ method requires 3 arguments.

        Args:

            message (str): The message would be the {ALERT.MESSAGE} macro from
                           Zabbix.

                           It should be formatted like the following

                           name: "{TRIGGER.NAME}"
                           id: "{TRIGGER.ID}"
                           status: "{TRIGGER.STATUS}"
                           hostname: "{HOSTNAME}"
                           event_id: "{EVENT.ID}"
                           severity: "{TRIGGER.SEVERITY}"
                           url: "{TRIGGER.URL}"
                           description: "{TRIGGER.DESCRIPTION}"

            token (str): The Flowdock source token
        """
        self.message = message
        self.token = token
	self.subject = subject

    def _parse(self):
        pattern = (r'name: *"(.*)"\s*id: *"(.*)"\s*status: *"(.*)"\s*hostname:'
                   r' *"(.*)"\s*event_id: *"(.*)"\s*severity: *"(.*)"\s*url: *'
                   r'"(.*)"\s*description: *"([\w\W\s]*)"')
        matches = re.match(pattern, self.message)
        return matches

    def _name(self):
        name = self._parse()
        return name.group(1)

    def _triggerid(self):
        triggerid = self._parse()
        return triggerid.group(2)

    def _status(self):
        status = self._parse()        
        return status.group(3)

    def _hostname(self):
        hostname = self._parse()
        return hostname.group(4)

    def _eventid(self):
        eventid = self._parse()
        return eventid.group(5)

    def _severity(self):
        sev = self._parse()
        return sev.group(6)

    def _url(self):
        url = self._parse()
        if url.group(7) == "":
            url = "#"
        else:
            url = url.group(7)
        return url

    def _description(self):
        """This is here for future use. It is not currently implemented."""
        desc = self._parse()
        return desc.group(8)

    def _sevassets(self):
        if self._severity() == "Not classified" or \
           self._severity() == "Information":
            color = "gray"
        elif self._severity() == "Warning" or self._severity() == "Average":
            color = "yellow"
        elif self._severity() == "High" or self._severity() == "Disaster":
            color = "red"
        if self._status() == "OK":
            color = "green"
        return (color)

    def _formatmessage(self):
        message = ("{0}:{1} \n <a href='"+self.zabbix_url+
                   "/tr_comments.php?triggerid={2}'>More Information</a> | "
                   "<a href='"+self.zabbix_url+"/events.php?"
                   "filter_set=1&triggerid={2}&period=604800'>Events</a> | "
                   "<a href='"+self.zabbix_url+"/zabbix.php?"
                   "action=acknowledge.edit&acknowledge_type=1&"
                   "eventids[]={3}&backurl=tr_status.php'>Acknowledge</a> | "
                   "<a href='{4}'>Trigger Link</a></b>") \
                    .format(self._status(), self._name(), self._triggerid(),
                            self._eventid(), self._url())
        return message

    def _card(self):
        card = {
            "flow_token": self.token,
            "event": "activity",
            "author": {
                "name": "Zabbix",
                "avatar": "https://sentia.com/favicon.ico"
            },
            "title": self._status(),
            "external_thread_id": self._eventid(),
            "thread": {
                "title": self._name(),
                "fields": [{"label": "Severity", "value": self._severity()}],
                "body": "Hostname: "+self._hostname()+"<br>"+"Trigger: "+self._name(),
                "external_url": self.zabbix_url+"/zabbix.php?action=acknowledge.edit&acknowledge_type=1&eventids[]="+self._eventid()+"&backurl=tr_status.php",
                "status": {
                    "color": self._sevassets(),
                    "value": self._status()
                }
            }
        }	
        #logging.info("Payload \n")
        #logging.info(card)
        return card

    def sendmsg(self):
        """Sends the message data to the Flowdock API.
           Call it after calling the Class with needed parameters
           to send the message"""
        payload = self._card()
        resp = requests.post('https://api.flowdock.com/messages',data=json.dumps(payload),headers=self.HEADERS)
	logging.info(resp)

def main():    
    logging.info(sys.argv[3])
    ZBXALERT = ZabbixAlert(sys.argv[1], sys.argv[2], sys.argv[3])
    ZBXALERT.sendmsg()


if __name__ == '__main__':
    main()
