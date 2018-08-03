#ifndef __SIMPLENIC_H
#define __SIMPLENIC_H

#include "endpoints/endpoint.h"

// TODO this should not be hardcoded here.
#define MAX_BANDWIDTH 200

// param: link latency in cycles
// assuming 3.2 GHz, this number / 3.2 = link latency in ns
// e.g. setting this to 6405 gives you 6405/3.2 = 2001.5625 ns latency
// IMPORTANT: this must be a multiple of 7
//#define LINKLATENCY 6405

class simplenic_t: public endpoint_t
{
    public:
        simplenic_t(simif_t* sim, char * slotid, uint64_t mac_little_end, int netbw, int netburst, int linklatency, char * niclogfile);
        ~simplenic_t();

        virtual void init();
        virtual void tick();
        virtual bool done();
        virtual bool stall() { return false; }

    private:
        simif_t* sim;
        uint64_t mac_lendian;
        char * pcis_read_bufs[2];
        char * pcis_write_bufs[2];
        int rlimit_inc, rlimit_period, rlimit_size;
        int LINKLATENCY;
        FILE * niclog;
};

#endif // __SIMPLENIC_H
