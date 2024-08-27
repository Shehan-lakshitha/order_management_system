import ballerina/http;
import ballerina/uuid;
import ballerinax/mongodb;


configurable string host = "localhost";
configurable int port = 27017;

configurable string URL = ?;



type Customer record {|
    string id;
    string name;
    string email;
    string address;
    string contactNumber;
    Order[] orders;
|};

type Order record {|
    string id;
    string customerId;
    string status;
    int quantity;
    decimal total;
|};

type CustomerInput record {|
    string name;
    string email;
    string address;
    string contactNumber;
|};

type OrderInput record {|
    string customerId;
    string status;
    int quantity;
    decimal total;
|};




final mongodb:Client mongoDb = check new ({
    connection: URL
});



service on new http:Listener(9092){

    private final mongodb:Database db;

    function  init() returns error? {
        self.db = check mongoDb->getDatabase("order_management");
    }

    resource function get customers() returns Customer[]|error {
        mongodb:Collection customersCollection = check self.db->getCollection("customers");
        stream<Customer, error?> resultStream = check customersCollection->aggregate([
            {
                \$lookup: {
                    'from: "orders",
                    localField: "id",
                    foreignField: "customerId",
                    'as: "orders"
                }
            }
        ]);
        return from Customer customer in resultStream select customer;
    };

    resource function post customers(CustomerInput input) returns error? {
        mongodb:Collection customersCollection = check self.db->getCollection("customers");
        string id = uuid:createType1AsString();
        Customer customer = {
            id,
            orders: [],
            ...input
        };
        check customersCollection->insertOne(customer);
    }

    resource function get customers/[string id]() returns Customer|error {
        mongodb:Collection customersCollection = check self.db->getCollection("customers");
        stream<Customer, error?> resultStream = check customersCollection->aggregate([
            {
                \$match: {
                    id: id
                }
            },
            {
                \$lookup: {
                    'from: "orders",
                    localField: "id",
                    foreignField: "customerId",
                    'as: "orders"
                }
            },
            {
                \$limit: 1
            },
            {
                \$project: {
                    id: 1,
                    name: 1,
                    email: 1,
                    address: 1,
                    contactNumber: 1,
                    orders: {
                        id: {"orders.id": 1},
                        customerId: {"orders.customerId": 1},
                        status: {"orders.status": 1},
                        quantity: {"orders.quantity": 1},
                        total: {"orders.total": 1}
                    }
                }
            }
        ]);
        record {Customer value;}|error? result = resultStream.next();
        if result is error? {
            return error(string `Cannot find the customer with id: ${id}`);
        }
        return result.value;
    }

    resource function post orders(OrderInput input) returns error? {
        mongodb:Collection ordersCollection = check self.db->getCollection("orders");
        string id = uuid:createType1AsString();
        Order 'order = {
            id,
            ...input
        };
        check ordersCollection->insertOne('order); 

        // mongodb:Collection customers = check self.db->getCollection("customers");

        // _ = check customers->updateOne(
        //     {
        //         id: input.customerId
        //     },
        //     {
        //         set:{
        //             orders: id
        //         }
        //     });  
        // };
        
    };
}

