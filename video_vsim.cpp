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

// 1 to save FST waveform trace file
#define VM_TRACE 1

// svpng header
#include "svpng/svpng.inc"

#include "verilated_fst_c.h" // for VM_TRACE

#define LOGDIR "logs/"

// Current simulation time (64-bit unsigned)
vluint64_t main_time = 0;

int frame_num;
volatile bool done;

int v_size = 0;
int h_size = 0;
int v_count = 0;
int h_count = 0;

int pixel_num;
uint8_t rgba[1920 * 1080 * 4];

char filename[256];

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
    const auto trace_path = LOGDIR "video_vsim.fst";
    logonly_printf("Writing FST waveform file to \"%s\"...\n", trace_path);
    VerilatedFstC *tfp = new VerilatedFstC;

    top->trace(tfp, 99); // trace to heirarchal depth of 99
    tfp->open(trace_path);
#endif

    bool new_frame = false;
    while (!done && !Verilated::gotFinish())
    {
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

        // look at vsync pin (gpio_46) to count frames
        static bool init_gpio_46;
        static bool prev_gpio_46;
        static vluint64_t last_frame_time;

        // look at hsync pin (gpio_2) to count lines
        static bool init_gpio_2;
        static bool prev_gpio_2;

        if (!main_time)
        {
            // capture initial state at time 0
            init_gpio_46 = top->gpio_46;
            init_gpio_2 = top->gpio_2;
        }

        h_count += 1;

        if (prev_gpio_2 != top->gpio_2 && top->gpio_2 == init_gpio_2)
        {
            if (h_count > h_size)
            {
                h_size = h_count;
            }

            h_count = 0;
            v_count += 1;
        }
        prev_gpio_2 = top->gpio_2;

        if (prev_gpio_46 != top->gpio_46 && top->gpio_46 == init_gpio_46)
        {
            if (v_count > v_size)
            {
                v_size = v_count;
            }
            v_count = 0;

            new_frame = true;
        }
        prev_gpio_46 = top->gpio_46;

        rgba[pixel_num++] = top->gpio_47 ? 0xff : 0x00;
        rgba[pixel_num++] = top->gpio_45 ? 0xff : 0x00;
        rgba[pixel_num++] = top->gpio_48 ? 0xff : 0x00;
        rgba[pixel_num++] = top->gpio_2 == init_gpio_2 || top->gpio_46 == init_gpio_46 ? 0x80 : 0xff;

        if (new_frame)
        {
            new_frame = false;

            if (frame_num)
            {
                printf("Frame %d completed (@ %" PRIu64 " clock cycles, %" PRIu64 " cycles for frame)\n", frame_num, main_time / 2, main_time / 2 - last_frame_time);

                snprintf(filename, sizeof(filename), LOGDIR "/upduino-video_f%02d.png", frame_num);

                // save frame here
                printf("Frame saved as \"%s\" (%d x %d)\n", filename, h_size, v_size);

                FILE *fp = fopen(filename, "w");
                if (fp)
                {

                    svpng(fp, h_size, v_size, rgba, 1);

                    fclose(fp);
                }
                else
                {
                    printf("Error writing.\n");
                }
            }

            pixel_num = 0;

            last_frame_time = main_time / 2;
            frame_num++;

            // exit after > 5 frames
            if (frame_num > 10)
            {
                printf("Maximum frames, stopping.\n");
                done = true;
            }
        }

        main_time++;

        // failsafe exit
        if ((main_time / 2) >= (uint64_t)25000000)
        {
            printf("Maximum time, stopping.\n");

            done = true;
        }
    }

    top->final();

#if VM_TRACE
    tfp->close();
#endif

    log_printf("Simulation ended after %lu clock ticks\n",
               (main_time / 2));

    return EXIT_SUCCESS;
}
