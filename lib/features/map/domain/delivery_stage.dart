enum DeliveryStage {
  headingToRestaurant,
  waitingOrder,
  headingToCustomer,
  waitingClient,
  delivered,
}

extension DeliveryStageText on DeliveryStage {
  String get label {
    switch (this) {
      case DeliveryStage.headingToRestaurant:
        return 'De camino a recoger';
      case DeliveryStage.waitingOrder:
        return 'Esperando pedido';
      case DeliveryStage.headingToCustomer:
        return 'Llevando pedido';
      case DeliveryStage.waitingClient:
        return 'Esperando al cliente';
      case DeliveryStage.delivered:
        return 'Entrega completada';
    }
  }

  String get hint {
    switch (this) {
      case DeliveryStage.headingToRestaurant:
        return 'Dirigete a SuperSuperBurguer para el recojo';
      case DeliveryStage.waitingOrder:
        return 'Confirma con el restaurante cuando el pedido este listo';
      case DeliveryStage.headingToCustomer:
        return 'Sigue la ruta hasta el cliente';
      case DeliveryStage.waitingClient:
        return 'Ya estas en destino, contacta al cliente si es necesario';
      case DeliveryStage.delivered:
        return 'Buen trabajo, la orden fue entregada';
    }
  }
}
