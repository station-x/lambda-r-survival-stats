#!/usr/bin/env python
# Copyright 2016 Station X, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import ctypes
import json
import os

# use python logging module to log to CloudWatch
# http://docs.aws.amazon.com/lambda/latest/dg/python-logging.html
import logging
logging.getLogger().setLevel(logging.DEBUG)

logging.debug('Start')

# must load all shared libraries and set the R environment variables before we can import rpy2
# load R shared libraries from lib dir
for file in os.listdir('lib'):
    if os.path.isfile(os.path.join('lib', file)):
        ctypes.cdll.LoadLibrary(os.path.join('lib', file))

# set R environment variables
os.environ["R_HOME"] = os.getcwd()
os.environ["R_LIBS"] = os.path.join(os.getcwd(), 'site-library')

# import rpy2
import rpy2
from rpy2 import robjects
from rpy2.robjects import r

def calculate_survival_stats(times, events, values_by_record):
    """
    @param times: time elapsed before the event occurs, or when subject is censored
    @param events: 1 indicates event was observed; 0 indicates event did not occur
    @param values_by_record: two dimensional double array.  Each row is the predictor values for a record (ex: gene)
    @return: array where each element contains the hazard ratio and pvalue for the record
    """
    # flatten values of two dimensional array for use by R
    # in R, matrices are simply an array where you specify number of columns per row
    logging.debug('Unpacking values')
    flattened_values = [y for row in values_by_record for y in row]

    logging.debug('Setting r variables')
    t = robjects.FloatVector(times)
    e = robjects.IntVector(events)
    v = robjects.FloatVector(flattened_values)

    # convert flattened values into an R matrix
    m = robjects.r['matrix'](v, nrow=len(values_by_record), byrow=True)

    #load R library
    r('library(survival)')

    # assign variables in R
    r.assign('valuesMatrix', m)
    r.assign('numSamples', len(times))
    r.assign('times', t)
    r.assign('events', e)

    # calculate statistics by applying coxph to each record's values
    logging.debug('Calculating stats')
    r("""res <- apply(valuesMatrix,1, function(values) {
      coxlist = try(coxph(Surv(times,events)~values + cluster(1:numSamples[1])))
      return(c(summary(coxlist)$coefficients[2], summary(coxlist)$coefficients[6]))
      })""")
    logging.debug('Done calculating stats')

    # convert results
    r_res = robjects.r['res']
    res_iter = iter(r_res)
    results = []
    for hazard in res_iter:
        pval = next(res_iter)
        results.append({'hazard': hazard, 'pval': pval})
    return results


def lambda_handler(event, context):
    logging.debug('In handler')
    times = event['times']
    events = event['events']
    # support receiving values (ex: expression) for multiple records (ex: genes)
    values_by_record = event['values_by_record']
    logging.info('Number of samples: {0}'.format(len(times)))
    logging.info('Number of genes/variants: {0}'.format(len(values_by_record)))

    try:
        stats_list = calculate_survival_stats(times, events, values_by_record)
        logging.debug('Done receiving stats ')
    except rpy2.rinterface.RRuntimeError, e:
        logging.error('Payload: {0}'.format(event))
        logging.error('Error: {0}'.format(e.message))

        # generate a JSON error response that API Gateway will parse and associate with a HTTP Status Code
        error = {}
        error['errorType'] = 'StatisticsError'
        error['httpStatus'] = 400
        error['request_id'] = context.aws_request_id
        error['message'] = e.message.replace('\n', ' ') # convert multi-line message into single line
        raise Exception(json.dumps(error))

    res = {}
    res['statistics_list'] = stats_list
    logging.debug('End')
    return res
