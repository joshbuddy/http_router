class HttpRouter
  class Node
    class UserAgent < AbstractRequestNode
      def initialize(router, parent, user_agents)
        super(router, parent, user_agents, :user_agent)
      end
    end
  end
end