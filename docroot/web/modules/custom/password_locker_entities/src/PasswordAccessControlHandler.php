<?php

namespace Drupal\password_locker_entities;

use Drupal\Core\Entity\EntityAccessControlHandler;
use Drupal\Core\Entity\EntityInterface;
use Drupal\Core\Session\AccountInterface;
use Drupal\Core\Access\AccessResult;

/**
 * Access controller for the Password entity.
 *
 * @see \Drupal\password_locker_entities\Entity\Password.
 */
class PasswordAccessControlHandler extends EntityAccessControlHandler {

  /**
   * {@inheritdoc}
   */
  protected function checkAccess(EntityInterface $entity, $operation, AccountInterface $account) {
    /** @var \Drupal\password_locker_entities\Entity\PasswordInterface $entity */

    switch ($operation) {

      case 'view':

        if (!$entity->isPublished()) {
          return AccessResult::allowedIfHasPermission($account, 'view unpublished password entities');
        }


        return AccessResult::allowedIfHasPermission($account, 'view published password entities');

      case 'update':

        return AccessResult::allowedIfHasPermission($account, 'edit password entities');

      case 'delete':

        return AccessResult::allowedIfHasPermission($account, 'delete password entities');
    }

    // Unknown operation, no opinion.
    return AccessResult::neutral();
  }

  /**
   * {@inheritdoc}
   */
  protected function checkCreateAccess(AccountInterface $account, array $context, $entity_bundle = NULL) {
    return AccessResult::allowedIfHasPermission($account, 'add password entities');
  }


}
