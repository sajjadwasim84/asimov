#!/bin/bash

timeout 1m srun -n1 -pTitanXx8 hostname || “body of the email” | /bin/mail -s "testmail" muhammadwasim@baidu.com
