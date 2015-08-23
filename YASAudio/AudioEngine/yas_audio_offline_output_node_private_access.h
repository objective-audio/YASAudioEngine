//
//  yas_audio_offline_output_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    class audio_offline_output_node::private_access
    {
       public:
        static start_result start(audio_offline_output_node *node, const render_function &callback_func,
                                  const completion_function &completion_func)
        {
            return node->_start(callback_func, completion_func);
        }

        static void stop(audio_offline_output_node *node)
        {
            node->_stop();
        }
    };
}
