//
//  yas_audio_connection_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if YAS_TEST

namespace yas
{
    class audio_connection::private_access
    {
       public:
        static audio_connection create(audio_node &source_node, const UInt32 source_bus, audio_node &destination_node,
                                       const UInt32 destination_bus, const audio_format &format)
        {
            return audio_connection(source_node, source_bus, destination_node, destination_bus, format);
        }

        static void remove_nodes(audio_connection &connection)
        {
            connection._remove_nodes();
        }

        static void remove_source_node(audio_connection &connection)
        {
            connection._remove_source_node();
        }

        static void remove_destination_node(audio_connection &connection)
        {
            connection._remove_destination_node();
        }
    };
}

#endif