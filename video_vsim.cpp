// C++ "driver" for UPduino video
//
// vim: set et ts=4 sw=4
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "verilated.h"

#include "Vvideo_top.h"

#define VM_TRACE 1
#define USE_FST 1 // FST format saves a lot of disk space vs older VCD
#if USE_FST
#include "verilated_fst_c.h" // for VM_TRACE
#else
#include "verilated_vcd_c.h" // for VM_TRACE
#endif

#define LOGDIR "logs/"

// Current simulation time (64-bit unsigned)
vluint64_t main_time = 0;

int frame_num;
volatile bool done;

static FILE *logfile;
static char log_buff[16384];

static void log_printf(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(log_buff, sizeof(log_buff), fmt, args);
    fputs(log_buff, stdout);
    fputs(log_buff, logfile);
    va_end(args);
}

static void logonly_printf(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    vsnprintf(log_buff, sizeof(log_buff), fmt, args);
    fputs(log_buff, logfile);
    va_end(args);
}

void ctrl_c(int s)
{
    (void)s;
    done = true;
}

// Called by $time in Verilog
double sc_time_stamp()
{
    return main_time;
}

int main(int argc, char **argv)
{
    struct sigaction sigIntHandler;

    sigIntHandler.sa_handler = ctrl_c;
    sigemptyset(&sigIntHandler.sa_mask);
    sigIntHandler.sa_flags = 0;

    sigaction(SIGINT, &sigIntHandler, NULL);

    if ((logfile = fopen(LOGDIR "video_vsim.log", "w")) == NULL)
    {
        printf("can't create " LOGDIR "video_vsim.log\n");
        exit(EXIT_FAILURE);
    }

    log_printf("\nSimulation started\n");

    Verilated::commandArgs(argc, argv);

#if VM_TRACE
    Verilated::traceEverOn(true);
#endif

    Vvideo_top *top = new Vvideo_top;

#if VM_TRACE
#if USE_FST
    const auto trace_path = LOGDIR "video_vsim.fst";
    logonly_printf("Writing FST waveform file to \"%s\"...\n", trace_path);
    VerilatedFstC *tfp = new VerilatedFstC;
#else
    const auto trace_path = LOGDIR "video_vsim.vcd";
    logonly_printf("Writing VCD waveform file to \"%s\"...\n", trace_path);
    VerilatedVcdC *tfp = new VerilatedVcdC;
#endif

    top->trace(tfp, 99); // trace to heirarchal depth of 99
    tfp->open(trace_path);
#endif

    //    top->reset_i = 1;        // start in reset

    while (!done && !Verilated::gotFinish())
    {
        if (main_time == 4)
        {
            //            top->reset_i = 0;        // tale out of reset after 2 cycles
        }

        top->gpio_20 = 1; // clock rising
        top->eval();

#if VM_TRACE
        tfp->dump(main_time);
#endif
        main_time++;

        top->gpio_20 = 0; // clock falling
        top->eval();

#if VM_TRACE
        tfp->dump(main_time);
#endif
        static bool init_gpio_46;
        static bool prev_gpio_46;
        static vluint64_t last_frame_time;

        if (!main_time)
        {
            init_gpio_46 = top->gpio_46;
        }
        else if (prev_gpio_46 != top->gpio_46 && top->gpio_46 == init_gpio_46)
        {
            if (frame_num)
            {
                printf("Frame %d completed (@ %llu clock cycles, %llu cycles for frame)\n", frame_num, main_time / 2, main_time / 2 - last_frame_time);
            }
            last_frame_time = main_time / 2;
            frame_num++;

            // exit after > 5 frames
            if (frame_num > 5)
            {
                done = true;
            }
        }
        prev_gpio_46 = top->gpio_46;

        // failsafe exit
        if (main_time >= (uint64_t)5000000)
        {
            done = true;
        }

        main_time++;
    }

    top->final();

#if VM_TRACE
    tfp->close();
#endif

    log_printf("Simulation ended after %lu clock ticks\n",
               (main_time / 2));

    return EXIT_SUCCESS;
}
